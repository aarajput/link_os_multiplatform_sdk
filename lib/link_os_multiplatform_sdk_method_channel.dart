import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'link_os_multiplatform_sdk_platform_interface.dart';

/// An implementation of [LinkOsMultiplatformSdkPlatform] that uses method channels.
class MethodChannelLinkOsMultiplatformSdk extends LinkOsMultiplatformSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('link_os_multiplatform_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
