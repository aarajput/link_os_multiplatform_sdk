package com.wisecrab.link_os_multiplatform_sdk

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.zebra.sdk.btleComm.BluetoothLeConnection
import com.zebra.sdk.btleComm.BluetoothLeDiscoverer
import com.zebra.sdk.printer.discovery.DiscoveredPrinter
import com.zebra.sdk.printer.discovery.DiscoveryHandler

class LinkOsMultiplatformSdkHostApiImpl(
    private val context: Context,
    private val flutterApi: LinkOsMultiplatformSdkFlutterApi
) :
    LinkOsMultiplatformSdkHostApi {

    var activity: Activity? = null
    private var requestBluetoothLePermissionsCallback: ((Result<Boolean>) -> Unit)? = null

    override fun requestBluetoothLePermissions(callback: (Result<Boolean>) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return callback(Result.success(true))
        }
        val requiredPermissions = arrayOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_FINE_LOCATION
        )
        val hasPermissions = requiredPermissions.all { permission ->
            ContextCompat.checkSelfPermission(
                context,
                permission
            ) == PackageManager.PERMISSION_GRANTED
        }
        if (hasPermissions) {
            return callback(Result.success(true))
        }
        if (activity == null) {
            return callback(Result.success(false))
        }
        requestBluetoothLePermissionsCallback = callback
        ActivityCompat.requestPermissions(
            activity!!,
            requiredPermissions,
            REQUEST_BLUETOOTH_LE
        )
    }

    override fun startBluetoothLeScanning(callback: (Result<Unit>) -> Unit) {
        try {
            BluetoothLeDiscoverer.findPrinters(
                context, BluetoothLeDiscovererHandler(
                    flutterApi = flutterApi,
                    callback = callback
                )
            )
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun printOverBluetoothLeWithoutParing(
        address: String,
        zpl: String,
        callback: (Result<Unit>) -> Unit
    ) {
        Thread {
            try {
                // Instantiate insecure connection for given Bluetooth MAC Address.
                val thePrinterConn = BluetoothLeConnection(address, context)

                // Initialize
                Looper.prepare()

                // Open the connection - physical connection is established here.
                thePrinterConn.open()

                // Send the data to printer as a byte array.
                thePrinterConn.write(zpl.toByteArray())

                // Make sure the data got to the printer before closing the connection
                Thread.sleep(500)

                // Close the insecure connection to release resources.
                thePrinterConn.close()
                callback(Result.success(Unit))

                Looper.myLooper()?.quit()
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }.start()
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String?>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == REQUEST_BLUETOOTH_LE && requestBluetoothLePermissionsCallback != null) {
            val granted =
                grantResults.isNotEmpty() &&
                        grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            requestBluetoothLePermissionsCallback!!.invoke(Result.success(granted))
            requestBluetoothLePermissionsCallback = null
            return true
        }
        return false
    }

    companion object {
        const val REQUEST_BLUETOOTH_LE = 1
    }
}

private class BluetoothLeDiscovererHandler(
    private val flutterApi: LinkOsMultiplatformSdkFlutterApi,
    private val callback: (Result<Unit>) -> Unit
) :
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
        callback(Result.success(Unit))
    }

    override fun discoveryError(error: String?) {
        callback(Result.failure(Exception(error)))
    }
}