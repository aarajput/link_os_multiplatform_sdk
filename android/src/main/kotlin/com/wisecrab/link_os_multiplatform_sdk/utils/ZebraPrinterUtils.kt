package com.wisecrab.link_os_multiplatform_sdk.utils

import com.zebra.sdk.comm.Connection
import com.zebra.sdk.printer.PrinterStatus
import com.zebra.sdk.printer.SGD
import com.zebra.sdk.printer.ZebraPrinter
import com.zebra.sdk.printer.ZebraPrinterFactory

/**
 * Utility class for common Zebra printer operations
 */
object ZebraPrinterUtils {

    /**
     * SGD parameter keys and values
     */
    object SGDParams {
        const val KEY_PRINTER_LANGUAGES = "device.languages"
        const val KEY_VIRTUAL_DEVICE = "apl.enable"
        const val VALUE_ZPL_LANGUAGE = "hybrid_xml_zpl"
        const val VALUE_PDF = "pdf"
        const val VALUE_NONE = "none"
    }

    /**
     * Checks if the printer is ready to print
     */
    fun isReadyToPrint(printer: ZebraPrinter): Boolean {
        return try {
            printer.currentStatus.isReadyToPrint
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Gets the current status of the printer
     */
    fun getPrinterStatus(printer: ZebraPrinter): PrinterStatus? {
        return try {
            printer.currentStatus
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Changes the printer language to ZPL if not already set
     */
    fun changePrinterLanguageToZpl(connection: Connection) {
        if (!connection.isConnected) {
            connection.open()
        }

        val printerLanguage = SGD.GET(SGDParams.KEY_PRINTER_LANGUAGES, connection)
        if (printerLanguage != SGDParams.VALUE_ZPL_LANGUAGE) {
            SGD.SET(SGDParams.KEY_PRINTER_LANGUAGES, SGDParams.VALUE_ZPL_LANGUAGE, connection)
        }
    }

    /**
     * Enables PDF Direct feature on the printer
     * @return true if the printer needs to be rebooted (Virtual Device was changed), false otherwise
     */
    fun enablePdfDirect(connection: Connection): Boolean {
        return setVirtualDevice(connection, SGDParams.VALUE_PDF)
    }

    /**
     * Disables PDF Direct feature on the printer (sets to none for ZPL printing)
     * @return true if the printer needs to be rebooted (Virtual Device was changed), false otherwise
     */
    fun disablePdfDirect(connection: Connection): Boolean {
        return setVirtualDevice(connection, SGDParams.VALUE_NONE)
    }

    /**
     * Sets the virtual device on the printer
     * @return true if the printer needs to be rebooted (Virtual Device was changed), false otherwise
     */
    private fun setVirtualDevice(connection: Connection, virtualDevice: String): Boolean {
        if (!connection.isConnected) {
            connection.open()
        }

        val currentVirtualDevice = SGD.GET(SGDParams.KEY_VIRTUAL_DEVICE, connection)

        if (currentVirtualDevice != virtualDevice) {
            SGD.SET(SGDParams.KEY_VIRTUAL_DEVICE, virtualDevice, connection)
            // Printer will automatically reboot when virtual device is changed
            return true
        }

        return false
    }

    /**
     * Creates a ZebraPrinter instance from a connection
     */
    fun getPrinterInstance(connection: Connection): ZebraPrinter {
        return ZebraPrinterFactory.getInstance(connection)
    }
}
