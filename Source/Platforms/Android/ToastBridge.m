//
//  ToastBridge.m
//  BridgeKitSample
//
//  Created by Ian Fischer on 2/24/15.
//  Copyright (c) 2015 Apportable. All rights reserved.
//

#import "ToastBridge.h"

@implementation ToastBridge

@bridge (constructor) initWithActivity:;
@bridge (method, instance) showToast: = showToast;
@bridge (callback) callbackFromJava: = callbackFromJava;
@bridge (field) toastCount = toastCount;


- (void)callbackFromJava:(NSString *)message {
    NSLog(@"Received a message from Java!  Java says: \"%@\"", message);
}

@end
