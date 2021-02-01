#import "PolarBleSdkPlugin.h"
#if __has_include(<polar_ble_sdk/polar_ble_sdk-Swift.h>)
#import <polar_ble_sdk/polar_ble_sdk-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "polar_ble_sdk-Swift.h"
#endif

@implementation PolarBleSdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftPolarBleSdkPlugin registerWithRegistrar:registrar];
}
@end
