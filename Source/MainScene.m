#import "MainScene.h"
#ifdef ANDROID
// These three undefs are currently needed to avoid conflicts with Android's Java implementation of EGL.
// Future versions of SBAndroid will not need these.
#undef EGL_NO_CONTEXT
#undef EGL_NO_DISPLAY
#undef EGL_NO_SURFACE
#import <AndroidKit/AndroidKit.h>
#import "ToastBridge.h"
#endif

@implementation MainScene

- (void)showAToast:(id)target {
    NSLog(@"showAToast");
#ifdef ANDROID
    dispatch_async(dispatch_get_main_queue(), ^{
        AndroidContext *context = [CCActivity currentActivity];
        AndroidToast *toast = [AndroidToast makeText:context charSequence:@"This is a toast!" duration:AndroidToastLengthShort];
        [toast show];
    });
#endif
}

- (void)showAnotherToast:(id)target {
    NSLog(@"showAnotherToast");
#ifdef ANDROID
    ToastBridge *toastBridge = [[ToastBridge alloc] initWithActivity:[CCActivity currentActivity]];
    NSLog(@"We have displayed %d of these toasts so far!", toastBridge.toastCount);
    [toastBridge showToast:@"Toast from Java!"];
#endif
}

@end
