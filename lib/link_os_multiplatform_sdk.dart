import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:link_os_multiplatform_sdk/link_os_multiplatform_sdk.pigeon.dart';
import 'package:link_os_multiplatform_sdk/utils/image_utils.dart';

/// Top-level function for [compute] to run image-to-ZPL conversion in an isolate.
String _convertImageToZplInIsolate(({Uint8List image, int threshold, int? labelWidth, int? labelHeight}) args) {
  return ImageUtils.convertImageToZpl(
    args.image,
    threshold: args.threshold,
    labelWidth: args.labelWidth,
    labelHeight: args.labelHeight,
  );
}

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
    return _hostApi.printZplOverBluetoothLeWithoutParing(address, zpl);
  }

  Future<void> printImageOverBluetoothLeWithoutParing(
    String address,
    Uint8List image, {
    int threshold = 128,
    int? labelWidth,
    int? labelHeight,
  }) async {
    // Convert image to ZPL format in an isolate to avoid blocking the UI
    final zpl = await compute(
      _convertImageToZplInIsolate,
      (image: image, threshold: threshold, labelWidth: labelWidth, labelHeight: labelHeight),
    );

    // Send ZPL to printer via Bluetooth LE
    return _hostApi.printZplOverBluetoothLeWithoutParing(address, zpl);
  }

  Future<void> printPDFOverBluetoothLeWithoutParing(
    String address,
    String pdfFilePath,
  ) {
    return _hostApi.printPDFOverBluetoothLeWithoutParing(address, pdfFilePath);
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
