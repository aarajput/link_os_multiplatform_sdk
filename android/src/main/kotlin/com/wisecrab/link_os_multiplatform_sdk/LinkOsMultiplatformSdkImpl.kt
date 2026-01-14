package com.wisecrab.link_os_multiplatform_sdk

import android.content.Context
import com.zebra.sdk.btleComm.BluetoothLeDiscoverer
import com.zebra.sdk.printer.discovery.DiscoveredPrinter
import com.zebra.sdk.printer.discovery.DiscoveryHandler

class LinkOsMultiplatformSdkHostApiImpl(
    private val context: Context,
    private val flutterApi: LinkOsMultiplatformSdkFlutterApi
) :
    LinkOsMultiplatformSdkHostApi {

    override fun startBluetoothLeScanning() {
        BluetoothLeDiscoverer.findPrinters(context, BluetoothLeDiscovererHandler(flutterApi))
    }
}

private class BluetoothLeDiscovererHandler(private val flutterApi: LinkOsMultiplatformSdkFlutterApi) :
    DiscoveryHandler {
    private val discoveredPrinters = mutableListOf<BluetoothLePrinterData>()
    override fun foundPrinter(printer: DiscoveredPrinter?) {
        if (printer == null) {
            return
        }
        val bluetoothLePrinter = BluetoothLePrinterData(
            name = printer.discoveryDataMap["FRIENDLY_NAME"] ?: "",
            address = printer.address
        )
        if (discoveredPrinters.indexOfFirst { it.address == bluetoothLePrinter.address } != -1) {
            return
        }
        discoveredPrinters.add(bluetoothLePrinter)
        flutterApi.onBluetoothLePrintersDetected(discoveredPrinters) {}
    }

    override fun discoveryFinished() {
        flutterApi.onBluetoothLeScanningFinished {}
    }

    override fun discoveryError(error: String?) {
        flutterApi.onBluetoothLeScanningError(error) {}
    }
}