import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/link_os_multiplatform_sdk.pigeon.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/wisecrab/link_os_multiplatform_sdk/LinkOsMultiplatformSdk.pigeon.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.wisecrab.link_os_multiplatform_sdk',
    ),
    swiftOut: 'ios/Classes/LinkOsMultiplatformSdk.pigeon.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'com.wisecrab.link_os_multiplatform_sdk',
  ),
)
@HostApi()
abstract class LinkOsMultiplatformSdkHostApi {
  void startBluetoothLeScanning();
}

class BluetoothLePrinterData {
  final String name;
  final String address;

  BluetoothLePrinterData({
    required this.name,
    required this.address,
  });
}

@FlutterApi()
abstract class LinkOsMultiplatformSdkFlutterApi {
  void onBluetoothLePrintersDetected(List<BluetoothLePrinterData> printerData);
  void onBluetoothLeScanningFinished();
  void onBluetoothLeScanningError(String? error);
}
