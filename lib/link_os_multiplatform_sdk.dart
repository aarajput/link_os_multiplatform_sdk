import 'dart:async';

import 'package:link_os_multiplatform_sdk/link_os_multiplatform_sdk.pigeon.dart';

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

  Future<void> printOverBluetoothLeWithoutParing(String address, String zpl) {
    return _hostApi.printOverBluetoothLeWithoutParing(address, zpl);
  }

  Future<bool> isBluetoothEnabled() {
    return _hostApi.isBluetoothEnabled();
  }

  Future<bool> requestBluetoothEnable() {
    return _hostApi.requestBluetoothEnable();
  }

  Future<bool> isLocationEnabled() {
    return _hostApi.isLocationEnabled();
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
