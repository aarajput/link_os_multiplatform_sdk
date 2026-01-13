import 'package:flutter_test/flutter_test.dart';
import 'package:link_os_multiplatform_sdk/link_os_multiplatform_sdk.dart';
import 'package:link_os_multiplatform_sdk/link_os_multiplatform_sdk_platform_interface.dart';
import 'package:link_os_multiplatform_sdk/link_os_multiplatform_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLinkOsMultiplatformSdkPlatform
    with MockPlatformInterfaceMixin
    implements LinkOsMultiplatformSdkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final LinkOsMultiplatformSdkPlatform initialPlatform = LinkOsMultiplatformSdkPlatform.instance;

  test('$MethodChannelLinkOsMultiplatformSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelLinkOsMultiplatformSdk>());
  });

  test('getPlatformVersion', () async {
    LinkOsMultiplatformSdk linkOsMultiplatformSdkPlugin = LinkOsMultiplatformSdk();
    MockLinkOsMultiplatformSdkPlatform fakePlatform = MockLinkOsMultiplatformSdkPlatform();
    LinkOsMultiplatformSdkPlatform.instance = fakePlatform;

    expect(await linkOsMultiplatformSdkPlugin.getPlatformVersion(), '42');
  });
}
