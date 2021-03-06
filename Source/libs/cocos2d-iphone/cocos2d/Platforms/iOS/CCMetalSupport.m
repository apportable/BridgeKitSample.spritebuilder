/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2013-2014 Cocos2D Authors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#import "CCMetalSupport_Private.h"
#if __CC_METAL_SUPPORTED_AND_ENABLED

#import "CCMetalView.h"
#import "CCTexture_Private.h"
#import "CCShader_Private.h"

#import "CCDeviceInfo.h"

@implementation CCMetalContext

-(instancetype)init
{
	if((self = [super init])){
		_device = MTLCreateSystemDefaultDevice();
		
		// Cannot use default.metallib to avoid clashing with Xcode build magic.
		// This is part of a workaround due to the iOS simulator not supporting Metal and may go away in the future.
		NSURL *url = [[NSBundle mainBundle] URLForResource:@"CCShaders.metallib" withExtension:nil];
		
		NSError *error = nil;
		_library = [_device newLibraryWithFile:[url path] error:&error];
		NSAssert(!error, @"Cannot load default CCShaders.metallib: %@", error);
		
		_commandQueue = [_device newCommandQueue];
		_currentCommandBuffer = [_commandQueue commandBuffer];
	}
	
	return self;
}

static NSString const *CCMetalContextCurrentKey = @"CCMetalContextCurrentKey";

+(instancetype)currentContext
{
	return [NSThread currentThread].threadDictionary[CCMetalContextCurrentKey];
}

+(void)setCurrentContext:(CCMetalContext *)context
{
	if(context){
		[NSThread currentThread].threadDictionary[CCMetalContextCurrentKey] = context;
	} else {
		[[NSThread currentThread].threadDictionary removeObjectForKey:CCMetalContextCurrentKey];
	}
}

-(void)endRenderPass
{
	[_currentRenderCommandEncoder endEncoding];
	_currentRenderCommandEncoder = nil;
}

-(void)beginRenderPass:(id<MTLTexture>)destinationTexture clearMask:(GLbitfield)mask color:(GLKVector4)color4 depth:(GLclampf)depth stencil:(GLint)stencil;
{
	// End the previous render pass.
	[self endRenderPass];
	
	MTLRenderPassColorAttachmentDescriptor *colorAttachment = [MTLRenderPassColorAttachmentDescriptor new];
	colorAttachment.texture = destinationTexture;
	if(mask & GL_COLOR_BUFFER_BIT){
		colorAttachment.loadAction = MTLLoadActionClear;
		colorAttachment.clearColor = MTLClearColorMake(color4.r, color4.g, color4.b, color4.a);
		colorAttachment.storeAction = MTLStoreActionStore;
	} else {
		colorAttachment.loadAction = MTLLoadActionDontCare;
		colorAttachment.storeAction = MTLStoreActionStore;
	}
	
	// TODO depth and stencil.

	MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
	renderPassDescriptor.colorAttachments[0] = colorAttachment;

	_currentRenderCommandEncoder = [_currentCommandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
	_destinationTexture = destinationTexture;
}

-(void)flushCommandBuffer
{
	[self endRenderPass];
	[_currentCommandBuffer commit];
	
	_currentCommandBuffer = [_commandQueue commandBuffer];
	_currentCommandBuffer.label = @"Main Cocos2D Command Buffer";
}

@end


@implementation CCTextureMetal

-(void)_setupTexture:(CCTextureType)type rendertexture:(BOOL)rendertexture sizeInPixels:(CGSize)sizeInPixels mipmapped:(BOOL)mipmapped;
{
    NSUInteger w = sizeInPixels.width;
    NSUInteger h = sizeInPixels.height;
    MTLPixelFormat format = (rendertexture ? MTLPixelFormatBGRA8Unorm : MTLPixelFormatRGBA8Unorm);
    MTLTextureDescriptor *textureDesc = nil;
    
    switch(type){
        case CCTextureType2D: textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:format width:w height:h mipmapped:mipmapped]; break;
        case CCTextureTypeCubemap: textureDesc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:format size:w mipmapped:mipmapped]; break;
    }
    
    NSAssert(textureDesc, @"Bad texture type?");
    _metalTexture = [[CCMetalContext currentContext].device newTextureWithDescriptor:textureDesc];
}

-(void)_setupSampler:(CCTextureType)type
    minFilter:(CCTextureFilter)minFilter magFilter:(CCTextureFilter)magFilter mipFilter:(CCTextureFilter)mipFilter
    addressX:(CCTextureAddressMode)addressX addressY:(CCTextureAddressMode)addressY
{
    MTLSamplerDescriptor *samplerDesc = [MTLSamplerDescriptor new];

    static const MTLSamplerMinMagFilter FILTERS[] = {
        MTLSamplerMinMagFilterLinear, // Invalid, fall back to linear.
        MTLSamplerMinMagFilterNearest,
        MTLSamplerMinMagFilterLinear,
    };

    static const MTLSamplerMipFilter MIP_FILTERS[] = {
        MTLSamplerMipFilterNotMipmapped,
        MTLSamplerMipFilterNearest,
        MTLSamplerMipFilterLinear,
    };

    samplerDesc.minFilter = FILTERS[minFilter];
    samplerDesc.magFilter = FILTERS[magFilter];
    samplerDesc.mipFilter = MIP_FILTERS[mipFilter];

    static const MTLSamplerAddressMode ADDRESSING[] = {
        MTLSamplerAddressModeClampToEdge,
        MTLSamplerAddressModeRepeat,
        MTLSamplerAddressModeMirrorRepeat,
    };

    samplerDesc.sAddressMode = ADDRESSING[addressX];
    samplerDesc.tAddressMode = ADDRESSING[addressY];

    _metalSampler = [[CCMetalContext currentContext].device newSamplerStateWithDescriptor:samplerDesc];
}

-(void)_uploadTexture2D:(CGSize)sizeInPixels miplevel:(NSUInteger)miplevel pixelData:(const void *)pixelData
{
    if(pixelData){
        NSUInteger bytesPerRow = sizeInPixels.width*4;
        [_metalTexture replaceRegion:MTLRegionMake2D(0, 0, sizeInPixels.width, sizeInPixels.height) mipmapLevel:miplevel withBytes:pixelData bytesPerRow:bytesPerRow];
    }
}

-(void)_uploadTextureCubeFace:(NSUInteger)face sizeInPixels:(CGSize)sizeInPixels miplevel:(NSUInteger)miplevel pixelData:(const void *)pixelData
{
    if(pixelData){
        NSUInteger bytesPerRow = sizeInPixels.width*4;
        [_metalTexture replaceRegion:MTLRegionMake2D(0, 0, sizeInPixels.width, sizeInPixels.height) mipmapLevel:miplevel slice:face withBytes:pixelData bytesPerRow:bytesPerRow bytesPerImage:0];
    }
}

-(void)_generateMipmaps:(CCTextureType)type
{
    CCMetalContext *context = [CCMetalContext currentContext];

    // Set up a command buffer for the blit operations.
    id<MTLCommandBuffer> blitCommands = [context.commandQueue commandBuffer];
    id<MTLBlitCommandEncoder> blitter = [blitCommands blitCommandEncoder];

    // Generate mipmaps and commit.
    [blitter generateMipmapsForTexture:_metalTexture];
    [blitter endEncoding];
    [blitCommands commit];
}
@end


@implementation CCGraphicsBufferMetal

-(instancetype)initWithCapacity:(NSUInteger)capacity elementSize:(size_t)elementSize type:(CCGraphicsBufferType)type;
{
	if((self = [super initWithCapacity:capacity elementSize:elementSize type:type])){
		// Use write combining? Buffers are already write only for the GL renderer.
		_buffer = [[CCMetalContext currentContext].device newBufferWithLength:capacity*elementSize options:MTLResourceOptionCPUCacheModeDefault];
		
		_ptr = _buffer.contents;
	}
	
	return self;
}

-(void)destroy {}

-(void)resize:(size_t)newCapacity;
{
	id<MTLBuffer> newBuffer = [[CCMetalContext currentContext].device newBufferWithLength:newCapacity*_elementSize options:MTLResourceOptionCPUCacheModeDefault];
	memcpy(newBuffer.contents, _ptr, _capacity*_elementSize);
	
	_capacity = newCapacity;
	_buffer = newBuffer;
	_ptr = _buffer.contents;
}

-(void)prepare;
{
	_count = 0;
}

-(void)commit; {}

@end


@implementation CCGraphicsBufferBindingsMetal

-(instancetype)init
{
	if((self = [super init])){
		CCRenderDispatch(NO, ^{
			_context = [CCMetalContext currentContext];
			
			const NSUInteger CCRENDERER_INITIAL_VERTEX_CAPACITY = 16*1024;
			_vertexBuffer = [[CCGraphicsBufferMetal alloc] initWithCapacity:CCRENDERER_INITIAL_VERTEX_CAPACITY elementSize:sizeof(CCVertex) type:CCGraphicsBufferTypeVertex];
			[_vertexBuffer prepare];
			
			_indexBuffer = [[CCGraphicsBufferMetal alloc] initWithCapacity:CCRENDERER_INITIAL_VERTEX_CAPACITY*1.5 elementSize:sizeof(uint16_t) type:CCGraphicsBufferTypeIndex];
			[_indexBuffer prepare];
			
			// Default to half a megabyte of initial uniform storage.
			NSUInteger uniformCapacity = 500*1024;
			_uniformBuffer = [[CCGraphicsBufferClass alloc] initWithCapacity:uniformCapacity elementSize:1 type:CCGraphicsBufferTypeUniform];
		});
	}
	
	return self;
}

@end


@implementation CCFrameBufferObjectMetal

-(instancetype)initWithTexture:(CCTexture *)texture depthStencilFormat:(GLuint)depthStencilFormat
{
	if((self = [super initWithTexture:texture depthStencilFormat:depthStencilFormat])){
		self.sizeInPixels = texture.sizeInPixels;
		self.contentScale = texture.contentScale;
		_frameBufferTexture = [(CCTextureMetal *)texture metalTexture];
	}
	
	return self;
}

-(void)bindWithClear:(GLbitfield)mask color:(GLKVector4)color4 depth:(GLclampf)depth stencil:(GLint)stencil
{
	[[CCMetalContext currentContext] beginRenderPass:_frameBufferTexture clearMask:mask color:color4 depth:depth stencil:stencil];
}

-(void)syncWithView:(CC_VIEW<CCView> *)view;
{
	[super syncWithView:view];
	_frameBufferTexture = [(CCMetalView *)view destinationTexture];
}

@end

#endif
