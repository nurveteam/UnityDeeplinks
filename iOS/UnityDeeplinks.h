#import "UnityAppController.h"


@interface UnityDeeplinksAppController : UnityAppController
{
}
// Temporary properties to store any deeplink information from UIApplicationDelegate.
// We use those only in case the UIApplicationDelegate started before the Unity controllers,
// which occurs when a deeplink is activated while the Unity app is not running:
@property id annotation;
@property NSString* sourceApplication;
@property NSDictionary* options;
@property NSURL* deeplink;

// Properties that hold the Unity object/method name to call upon deeplink:
@property NSString* gameObjectName;
@property NSString* deeplinkMethodName;

@end



