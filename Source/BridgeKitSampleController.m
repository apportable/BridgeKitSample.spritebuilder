//
//  BridgeKitSampleController.m
//  BridgeKitSample
//


#import "BridgeKitSampleController.h"

static BridgeKitSampleController *__sharedController;

@implementation BridgeKitSampleController

#pragma mark Application Setup


- (void)setupApplication
{
    [super setupApplication];
    
    /*
        Add your custom application logic + initialization here
    */
    
}

- (NSString *)firstSceneName
{
    return @"MainScene";
}

#pragma mark Android

#if __CC_PLATFORM_ANDROID

/*
    Add any android specific overrides here
*/

#endif


#pragma mark Mac

#if __CC_PLATFORM_MAC

/*
    Add any Mac specific overrides here
*/
-(CGSize)defaultWindowSize
{
    return CGSizeMake(480.0f, 320.0f);
}

#endif


#pragma mark Singleton Methods

/*
    These methods are used in the framework to reference this controller.
 */
+ (BridgeKitSampleController*)sharedController
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        __sharedController = [[BridgeKitSampleController alloc] init];
    });
    
    return __sharedController;
}


+ (void)setupApplication
{
    static dispatch_once_t setupToken;
    dispatch_once(&setupToken, ^
    {
        [[BridgeKitSampleController sharedController] setupApplication];
    });
}

@end
