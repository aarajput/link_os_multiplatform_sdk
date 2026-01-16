import 'dart:async';

import 'package:flutter/material.dart';
import 'package:link_os_multiplatform_sdk/link_os_multiplatform_sdk.dart';
import 'package:link_os_multiplatform_sdk/link_os_multiplatform_sdk.pigeon.dart';

class BluetoothLeDiscoveryPage extends StatefulWidget {
  const BluetoothLeDiscoveryPage({super.key});

  @override
  State<BluetoothLeDiscoveryPage> createState() =>
      _BluetoothLeDiscoveryPageState();
}

class _BluetoothLeDiscoveryPageState extends State<BluetoothLeDiscoveryPage> {
  List<BluetoothLePrinterData> _printers = [];
  StreamSubscription<List<BluetoothLePrinterData>>? _subscription;
  bool _isScanning = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _printers = [];
    });

    try {
      final hasPermissions = await LinkOsMultiplatformSdk.instance
          .requestBluetoothLePermissions();
      if (!hasPermissions) {
        setState(() {
          _isScanning = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bluetooth LE permissions denied')),
          );
        }
        return;
      }

      _subscription = LinkOsMultiplatformSdk
          .instance
          .onBluetoothLePrintersDetected
          .listen((printers) {
            setState(() {
              _printers = printers;
            });
          });

      await LinkOsMultiplatformSdk.instance.startBluetoothLeScanning();
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting scan: $e')));
      }
    }
  }

  Future<void> _printToPrinter(BluetoothLePrinterData printer) async {
    setState(() {
      _isPrinting = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      const sampleZpl = '^XA^FO20,20^A0N,25,25^FDTest Print^FS^XZ';
      await LinkOsMultiplatformSdk.instance.printOverBluetoothLeWithoutParing(
        printer.address,
        sampleZpl,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Print job sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error printing: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth LE Discovery')),
      body: _isScanning
          ? _printers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _printers.length,
                    itemBuilder: (context, index) {
                      final printer = _printers[index];
                      return ListTile(
                        title: Text(
                          printer.name.isEmpty ? 'Unknown' : printer.name,
                        ),
                        subtitle: Text(printer.address),
                        onTap: _isPrinting
                            ? null
                            : () => _printToPrinter(printer),
                      );
                    },
                  )
          : const Center(child: Text('Scanning stopped')),
    );
  }
}
