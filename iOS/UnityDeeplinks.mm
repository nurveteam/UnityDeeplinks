#ifndef __has_feature
#define __has_feature(x) 0 /* for non-clang compilers */
#endif

#if !__has_feature(objc_arc)
#error ARC must be enabled by adding -fobjc-arc under your target => Build Phases => Compile Sources => UnityDeeplinks.mm => Compiler Flags
#endif

#import <UIKit/UIKit.h>

#import "AppDelegateListener.h"
#import "UnityDeeplinks.h"



extern "C" {
    // There is no public unity header, need to declare this manually:
    // http://answers.unity3d.com/questions/58322/calling-unitysendmessage-requires-which-library-on.html
    extern void UnitySendMessage(const char *, const char *, const char *);
    
    // Forward declarations needed for some ObjC internal code:
    void UnityDeeplinks_init(const char* gameObject, const char* deeplinkMethod);
    void UnityDeeplinks_dispatch(NSString* message);
    
}



@interface UnityDeeplinksNotificationObserver : NSObject <AppDelegateListener>
- (void)onNotification:(NSNotification*)notification;
- (void)onOpenURL:(NSNotification *)notification;
@end


@implementation UnityDeeplinksNotificationObserver

+ (UnityDeeplinksNotificationObserver*)instance {
    static UnityDeeplinksNotificationObserver* singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[self alloc] init];
    });
    return singleton;
}

- (void)onNotification:(NSNotification*)notification {
    if (![kUnityOnOpenURL isEqualToString:notification.name]) return;
    NSURL* url = [notification.userInfo objectForKey:@"url"];
    if (url == nil) {
        NSLog(@"UnityDeeplinks: unexpected missing url in kUnityOnOpenURL notification");
        return;
    }
    [self dispatch:[url absoluteString]];
}

- (void)onOpenURL:(NSNotification *)notification {
    [self onNotification:notification];
}



- (void)dispatch:(NSString*)message {
    UnityDeeplinksAppController* ac = (UnityDeeplinksAppController*)GetAppController();
    const char* name = (const char*) [ac.gameObjectName UTF8String];
    const char* level = (const char*) [ac.deeplinkMethodName UTF8String];
    const char* code = (const char*) [message UTF8String];
    UnitySendMessage(name, level, code);
}


@end



@implementation UnityDeeplinksAppController

// iOS >= 9.0
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options {
    NSString *sourceApplication = options[UIApplicationOpenURLOptionsSourceApplicationKey];
    self.options = options;
    return [self application:app openURL:url sourceApplication:sourceApplication annotation:[NSDictionary dictionary]];
}



// iOS < 9.0
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    self.deeplink = url;
    self.sourceApplication = sourceApplication;
    self.annotation = annotation;
    return [super application:application openURL:url sourceApplication:sourceApplication annotation:annotation];
}



// Universal links:
- (BOOL)application:(UIApplication *)application continueUserActivity:(nonnull NSUserActivity *)userActivity restorationHandler:(nonnull void (^)(NSArray * _Nullable))restorationHandler {
    // App was opened from a Universal Link
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        [self application:application openURL:userActivity.webpageURL sourceApplication:nil annotation:[NSDictionary dictionary]];
    }
    return YES;
}


@end

// Comment out IMPL_APP_CONTROLLER_SUBCLASS to avoid multiple IMPL_APP_CONTROLLER_SUBCLASS call
// Tell Unity to use UnityDeeplinksAppController as the main app controller:
//IMPL_APP_CONTROLLER_SUBCLASS(UnityDeeplinksAppController)



extern "C" {
    
    static NSString* gameObjectName = @"UnityDeeplinks";
    static NSString* deeplinkMethodName = @"onDeeplink";
    
    
    void UnityDeeplinks_init(const char* gameObject, const char* deeplinkMethod) {
        UnityDeeplinksAppController* ac = (UnityDeeplinksAppController*)GetAppController();
        ac.gameObjectName = gameObjectName;
        if (gameObject != nil) {
            NSString* gameObjectStr = [NSString stringWithCString:gameObject encoding:NSUTF8StringEncoding];
            if ([gameObjectStr length] > 0)
            ac.gameObjectName = gameObjectStr;
        }
        
        ac.deeplinkMethodName = deeplinkMethodName;
        if (deeplinkMethod != nil) {
            NSString* deeplinkMethodStr = [NSString stringWithCString:deeplinkMethod encoding:NSUTF8StringEncoding];
            if ([deeplinkMethodStr length] > 0)
            ac.deeplinkMethodName = deeplinkMethodStr;
        }
        UnityRegisterAppDelegateListener([UnityDeeplinksNotificationObserver instance]);
        
        // During init, it's possible that the UIApplicationDelegate already started via a deeplink
        // and stored its data in temporary properties (in case the app was not previously running).
        // If so, handle the deeplink as soon as possible:
        if (ac.deeplink != nil) {
            NSURL* deeplink = ac.deeplink;
            ac.deeplink = nil;
            [ac application:[UIApplication sharedApplication] openURL:deeplink options:ac.options];
        }
        
    }
    
    
    
    
}
