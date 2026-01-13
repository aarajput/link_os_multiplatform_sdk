import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'link_os_multiplatform_sdk_method_channel.dart';

abstract class LinkOsMultiplatformSdkPlatform extends PlatformInterface {
  /// Constructs a LinkOsMultiplatformSdkPlatform.
  LinkOsMultiplatformSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static LinkOsMultiplatformSdkPlatform _instance = MethodChannelLinkOsMultiplatformSdk();

  /// The default instance of [LinkOsMultiplatformSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelLinkOsMultiplatformSdk].
  static LinkOsMultiplatformSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LinkOsMultiplatformSdkPlatform] when
  /// they register themselves.
  static set instance(LinkOsMultiplatformSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
