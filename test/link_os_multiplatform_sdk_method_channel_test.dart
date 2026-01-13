import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_os_multiplatform_sdk/link_os_multiplatform_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelLinkOsMultiplatformSdk platform = MethodChannelLinkOsMultiplatformSdk();
  const MethodChannel channel = MethodChannel('link_os_multiplatform_sdk');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
