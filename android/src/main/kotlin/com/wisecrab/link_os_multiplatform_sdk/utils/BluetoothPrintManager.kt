package com.wisecrab.link_os_multiplatform_sdk.utils

import android.content.Context
import android.os.Looper
import com.zebra.sdk.btleComm.BluetoothLeConnection
import com.zebra.sdk.printer.ZebraPrinter
import com.zebra.sdk.util.internal.FileUtilities
import java.io.File
import java.io.FileInputStream

/**
 * Manager class for handling Bluetooth LE printing operations
 */
class BluetoothPrintManager(
    private val context: Context,
    private val address: String
) {

    /**
     * Print ZPL data over Bluetooth LE without pairing
     */
    fun printZpl(zpl: String) {
        val connection = BluetoothLeConnection(address, context)
        var printer: ZebraPrinter? = null
        var looperCreated = false

        try {
            // Initialize Looper if needed
            if (Looper.myLooper() == null) {
                Looper.prepare()
                looperCreated = true
            }

            // Open the connection
            connection.open()

            // Get printer instance
            printer = ZebraPrinterUtils.getPrinterInstance(connection)

            // Check if printer is ready
            if (!ZebraPrinterUtils.isReadyToPrint(printer)) {
                val status = ZebraPrinterUtils.getPrinterStatus(printer)
                throw IllegalStateException("Printer is not ready to print. Status: $status")
            }

            // Disable PDF Direct if enabled (for ZPL printing)
            val needsReboot = ZebraPrinterUtils.disablePdfDirect(connection)
            if (needsReboot) {
                throw IllegalStateException(
                    "Printer needs to be rebooted to disable PDF Direct feature. " +
                            "Please reboot the printer and try again."
                )
            }

            // Set printer language to ZPL
            ZebraPrinterUtils.changePrinterLanguageToZpl(connection)

            // Send the ZPL data as bytes
            connection.write(zpl.toByteArray())

            // Wait for data to be sent to printer
            Thread.sleep(500)

            // Close the connection
            connection.close()
        } finally {
            // Clean up looper only if we created it
            if (looperCreated) {
                Looper.myLooper()?.quit()
            }
        }
    }

    /**
     * Print PDF file over Bluetooth LE without pairing
     */
    fun printPdf(pdfFilePath: String) {
        val file = File(pdfFilePath)
        if (!file.exists()) {
            throw IllegalArgumentException("PDF file does not exist: $pdfFilePath")
        }

        val connection = BluetoothLeConnection(address, context)
        var printer: ZebraPrinter? = null
        var looperCreated = false

        try {
            // Initialize Looper if needed
            if (Looper.myLooper() == null) {
                Looper.prepare()
                looperCreated = true
            }

            // Open the connection
            connection.open()

            // Get printer instance
            printer = ZebraPrinterUtils.getPrinterInstance(connection)

            // Check if printer is ready
            if (!ZebraPrinterUtils.isReadyToPrint(printer)) {
                val status = ZebraPrinterUtils.getPrinterStatus(printer)
                throw IllegalStateException("Printer is not ready to print. Status: $status")
            }

            // Enable PDF Direct feature
            val needsReboot = ZebraPrinterUtils.enablePdfDirect(connection)
            if (needsReboot) {
                throw IllegalStateException(
                    "Printer needs to be rebooted to enable PDF Direct feature. " +
                            "Please reboot the printer and try again."
                )
            }

            // Send PDF file in chunks
            FileInputStream(file).use { inputStream ->
                FileUtilities.sendFileContentsInChunks(connection, inputStream)
            }

            // Wait for data to be sent to printer
            Thread.sleep(500)

            // Close the connection
            connection.close()
        } finally {
            // Clean up looper only if we created it
            if (looperCreated) {
                Looper.myLooper()?.quit()
            }
        }
    }

    /**
     * Common method to execute a print job in a background thread
     */
    companion object {
        fun executePrintJob(printJob: () -> Unit, callback: (Result<Unit>) -> Unit) {
            Thread {
                try {
                    printJob()
                    callback(Result.success(Unit))
                } catch (e: Exception) {
                    e.printStackTrace()
                    callback(Result.failure(e))
                }
            }.start()
        }
    }
}
