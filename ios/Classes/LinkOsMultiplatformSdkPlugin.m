#import "LinkOsMultiplatformSdkPlugin.h"
#if __has_include(<link_os_multiplatform_sdk/link_os_multiplatform_sdk-Swift.h>)
#import <link_os_multiplatform_sdk/link_os_multiplatform_sdk-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "link_os_multiplatform_sdk-Swift.h"
#endif

@implementation LinkOsMultiplatformSdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [SwiftLinkOsMultiplatformSdkPlugin registerWithRegistrar:registrar];
}
@end
