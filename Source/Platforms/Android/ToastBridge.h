//
//  ToastBridge.h
//  BridgeKitSample
//
//  Created by Ian Fischer on 2/24/15.
//  Copyright (c) 2015 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AndroidKit/AndroidActivity.h>

BRIDGE_CLASS("com.apportable.bridgekitsample.ToastBridge")
@interface ToastBridge : JavaObject
- (instancetype)initWithActivity:(AndroidActivity *)activity;
- (void)callbackFromJava:(NSString *)message;
- (void)showToast:(NSString *)text;

@property (nonatomic, readonly) int toastCount;
@end
