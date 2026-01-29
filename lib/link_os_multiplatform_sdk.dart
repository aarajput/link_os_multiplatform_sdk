import 'dart:async';
import 'dart:typed_data';

import 'package:link_os_multiplatform_sdk/link_os_multiplatform_sdk.pigeon.dart';
import 'package:link_os_multiplatform_sdk/utils/image_utils.dart';

class LinkOsMultiplatformSdk {
  static final instance = LinkOsMultiplatformSdk._();
  final _hostApi = LinkOsMultiplatformSdkHostApi();
  late final _LinkOsMultiplatformSdkFlutterApiImpl _flutterApi;

  final _onBluetoothLePrintersDetectedController =
      StreamController<List<BluetoothLePrinterData>>.broadcast();
  Stream<List<BluetoothLePrinterData>> get onBluetoothLePrintersDetected =>
      _onBluetoothLePrintersDetectedController.stream;

  LinkOsMultiplatformSdk._() {
    _flutterApi = _LinkOsMultiplatformSdkFlutterApiImpl(
      onBluetoothLePrintersDetectedController:
          _onBluetoothLePrintersDetectedController,
    );

    LinkOsMultiplatformSdkFlutterApi.setUp(_flutterApi);
  }

  Future<void> startBluetoothLeScanning() {
    return _hostApi.startBluetoothLeScanning();
  }

  Future<bool> requestBluetoothLePermissions() {
    return _hostApi.requestBluetoothLePermissions();
  }

  Future<void> printZplOverBluetoothLeWithoutParing(
    String address,
    String zpl,
  ) {
    return _hostApi.printOverBluetoothLeWithoutParing(address, zpl);
  }

  Future<void> printImageOverBluetoothLeWithoutParing(
    String address,
    Uint8List image, {
    int threshold = 128,
    int? labelWidth,
    int? labelHeight,
  }) {
    // Convert image to ZPL format
    final zpl = ImageUtils.convertImageToZpl(
      image,
      threshold: threshold,
      labelWidth: labelWidth,
      labelHeight: labelHeight,
    );

    // Send ZPL to printer via Bluetooth LE
    return _hostApi.printOverBluetoothLeWithoutParing(address, zpl);
  }

  Future<bool> requestBluetoothEnable() {
    return _hostApi.requestBluetoothEnable();
  }

  Future<bool> requestLocationEnable() {
    return _hostApi.requestLocationEnable();
  }
}

class _LinkOsMultiplatformSdkFlutterApiImpl
    implements LinkOsMultiplatformSdkFlutterApi {
  final StreamController onBluetoothLePrintersDetectedController;
  _LinkOsMultiplatformSdkFlutterApiImpl({
    required this.onBluetoothLePrintersDetectedController,
  });
  @override
  void onBluetoothLePrintersDetected(
    List<BluetoothLePrinterData> printers,
  ) {
    onBluetoothLePrintersDetectedController.sink.add(printers);
  }
}
