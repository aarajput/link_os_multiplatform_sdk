
import 'link_os_multiplatform_sdk_platform_interface.dart';

class LinkOsMultiplatformSdk {
  Future<String?> getPlatformVersion() {
    return LinkOsMultiplatformSdkPlatform.instance.getPlatformVersion();
  }
}
