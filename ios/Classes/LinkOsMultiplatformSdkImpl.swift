//
//  LinkOsMultiplatformSdkImpl.swift
//  link_os_multiplatform_sdk
//
//  Created by Ali Abbas on 17/01/2026.
//

import CoreBluetooth
import ExternalAccessory
import Foundation

// Zebra printer BLE service UUIDs
private let ZPRINTER_SERVICE_UUID = CBUUID(string: "38EB4A80-C570-11E3-9507-0002A5D5C51B")
private let WRITE_TO_ZPRINTER_CHARACTERISTIC_UUID = CBUUID(
    string: "38EB4A82-C570-11E3-9507-0002A5D5C51B")
private let READ_FROM_ZPRINTER_CHARACTERISTIC_UUID = CBUUID(
    string: "38EB4A81-C570-11E3-9507-0002A5D5C51B")

class LinkOsMultiplatformSdkHostApiImpl: NSObject, LinkOsMultiplatformSdkHostApi,
    CBCentralManagerDelegate, CBPeripheralDelegate
{

    private let flutterApi: LinkOsMultiplatformSdkFlutterApi
    private var bluetoothPermissionCompletion: ((Result<Bool, Error>) -> Void)?
    private var bluetoothStateCompletion: ((Result<Bool, Error>) -> Void)?
    private var centralManager: CBCentralManager?
    private var bluetoothStateManager: CBCentralManager?
    private var scanningCompletion: ((Result<Void, Error>) -> Void)?
    private var discoveredPrinters: [String: BluetoothLePrinterData] = [:]
    private var discoveredPeripherals: [String: CBPeripheral] = [:]  // Store peripherals by UUID
    private var isScanning: Bool = false

    // Printing state
    private var printCompletion: ((Result<Void, Error>) -> Void)?
    private var printPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var printZplData: Data?
    private var targetAddress: String?  // MAC address or UUID to connect to
    private var isConnectingDirectly: Bool = false

    init(flutterApi: LinkOsMultiplatformSdkFlutterApi) {
        self.flutterApi = flutterApi
        super.init()
    }

    func requestBluetoothLePermissions(completion: @escaping (Result<Bool, Error>) -> Void) {
        // Check current Bluetooth authorization
        let bluetoothAuth: CBManagerAuthorization
        if #available(iOS 13.1, *) {
            bluetoothAuth = CBManager.authorization
        } else {
            // For iOS < 13.1, authorization is implicit
            bluetoothAuth = .allowedAlways
        }

        // If already authorized, return success
        if bluetoothAuth == .allowedAlways {
            return completion(.success(true))
        }

        // If Bluetooth is denied or restricted, return false
        if bluetoothAuth == .denied || bluetoothAuth == .restricted {
            return completion(.success(false))
        }

        // Store completion handler
        bluetoothPermissionCompletion = completion

        // Request Bluetooth permission by creating a CBCentralManager
        // This will trigger the permission dialog if not determined
        if bluetoothAuth == .notDetermined {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        } else {
            // Already determined but not granted
            checkAndCompletePermissions()
        }
    }

    private func checkAndCompletePermissions() {
        guard let completion = bluetoothPermissionCompletion else { return }

        let bluetoothAuth: CBManagerAuthorization
        if #available(iOS 13.1, *) {
            bluetoothAuth = CBManager.authorization
        } else {
            bluetoothAuth = centralManager?.state == .unauthorized ? .denied : .allowedAlways
        }

        if bluetoothAuth == .allowedAlways {
            bluetoothPermissionCompletion = nil
            completion(.success(true))
        } else if bluetoothAuth == .denied || bluetoothAuth == .restricted {
            bluetoothPermissionCompletion = nil
            completion(.success(false))
        } else if bluetoothAuth != .notDetermined {
            // Permission is determined but not granted
            bluetoothPermissionCompletion = nil
            completion(.success(false))
        }
        // If still not determined, wait for delegate callbacks
    }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if bluetoothPermissionCompletion != nil {
            checkAndCompletePermissions()
        }
        if bluetoothStateCompletion != nil {
            checkBluetoothState(central)
        }
        // If we're waiting to start scanning and Bluetooth is now powered on, start scanning
        if isScanning && scanningCompletion != nil && central.state == .poweredOn {
            startScanning()
        }
    }

    func requestBluetoothEnable(completion: @escaping (Result<Bool, Error>) -> Void) {
        // Check if we already have a manager with known state
        if let manager = centralManager, manager.state != .unknown {
            return completion(checkBluetoothStateResult(manager.state))
        }

        // Store completion handler
        bluetoothStateCompletion = completion

        // Create a new manager to check Bluetooth state
        // The delegate callback will be called when state is determined
        bluetoothStateManager = CBCentralManager(delegate: self, queue: nil)

        // If state is already known (shouldn't happen but check anyway)
        if let manager = bluetoothStateManager, manager.state != .unknown {
            let result = checkBluetoothStateResult(manager.state)
            bluetoothStateCompletion = nil
            bluetoothStateManager = nil
            completion(result)
        }
    }

    private func checkBluetoothState(_ central: CBCentralManager) {
        guard let completion = bluetoothStateCompletion else { return }

        let result = checkBluetoothStateResult(central.state)
        bluetoothStateCompletion = nil
        bluetoothStateManager = nil
        completion(result)
    }

    private func checkBluetoothStateResult(_ state: CBManagerState) -> Result<Bool, Error> {
        switch state {
        case .poweredOn:
            return .success(true)
        case .unauthorized:
            return .failure(
                NSError(
                    domain: "LinkOsMultiplatformSdk",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Bluetooth access is unauthorized"]
                ))
        case .poweredOff, .unsupported, .resetting, .unknown:
            return .success(false)
        @unknown default:
            return .success(false)
        }
    }

    func startBluetoothLeScanning(completion: @escaping (Result<Void, Error>) -> Void) {
        // Reset discovered printers
        discoveredPrinters.removeAll()

        // Ensure we have a central manager
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }

        guard let manager = centralManager else {
            let error = NSError(
                domain: "LinkOsMultiplatformSdk",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to initialize Bluetooth central manager"
                ]
            )
            completion(.failure(error))
            return
        }

        // Check Bluetooth state
        switch manager.state {
        case .poweredOn:
            // Bluetooth is on, start scanning immediately
            scanningCompletion = completion
            isScanning = true
            startScanning()

        case .poweredOff, .unauthorized, .unsupported, .resetting:
            let error = NSError(
                domain: "LinkOsMultiplatformSdk",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Bluetooth is not available or not powered on"
                ]
            )
            completion(.failure(error))

        case .unknown:
            // State is unknown, wait for delegate callback
            scanningCompletion = completion
            isScanning = true

        @unknown default:
            let error = NSError(
                domain: "LinkOsMultiplatformSdk",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unknown Bluetooth state"]
            )
            completion(.failure(error))
        }
    }

    private func startScanning() {
        guard let manager = centralManager, manager.state == .poweredOn else {
            return
        }

        // Scan for ALL BLE devices nearby by searching through the BLE advertisements.
        // Zebra printer broadcasts its printer names in the advertisement.
        // We use nil for services because Zebra printers don't broadcast services in advertisements.
        manager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )

        debugPrint("Started BLE scanning for Zebra printers")

        // Complete the scanning start request
        if let completion = scanningCompletion {
            scanningCompletion = nil
            completion(.success(()))
        }
    }

    // This callback comes whenever a BLE printer is discovered
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // If we're connecting directly, check if this is the target device
        if isConnectingDirectly, let targetAddr = targetAddress {
            let peripheralUUID = peripheral.identifier.uuidString

            // Check if this is a UUID format (contains hyphens)
            let isUUIDFormat = targetAddr.contains("-")

            if isUUIDFormat {
                // Target is a UUID - only connect if UUIDs match exactly
                if peripheralUUID.lowercased() == targetAddr.lowercased() {
                    debugPrint(
                        "Found target device by UUID during direct connection: \(peripheralUUID)")
                    central.stopScan()
                    isConnectingDirectly = false

                    printPeripheral = peripheral
                    peripheral.delegate = self
                    central.connect(peripheral, options: nil)
                    return
                } else {
                    // UUID doesn't match, skip this device
                    debugPrint(
                        "Skipping device \(peripheralUUID) - doesn't match target UUID \(targetAddr)"
                    )
                    return
                }
            } else {
                // Target is a MAC address or other format - connect to first device with a name
                // (Zebra printers typically broadcast their name)
                if let peripheralName = peripheral.name, !peripheralName.isEmpty {
                    let trimmedName = peripheralName.trimmingCharacters(in: .whitespaces)
                    debugPrint(
                        "Found device during direct connection (MAC mode): \(trimmedName) (\(peripheralUUID)), RSSI: \(RSSI)"
                    )

                    // Stop scanning and connect to this device
                    central.stopScan()
                    isConnectingDirectly = false

                    printPeripheral = peripheral
                    peripheral.delegate = self
                    central.connect(peripheral, options: nil)
                    return
                }

                // If no name, skip this device
                return
            }
        }

        // For regular scanning, filter by RSSI
        // Reject any where the value is above reasonable range
        if RSSI.intValue > -15 {
            return
        }

        // Reject if the signal strength is too low to be close enough (Close is around -22dB)
        if RSSI.intValue < -70 {
            return
        }

        // Ok, it's in the range. Let's add the device if it has a name
        guard let peripheralName = peripheral.name, !peripheralName.isEmpty else {
            return
        }

        // Remove leading & trailing whitespace in peripheral.name
        let trimmedName = peripheralName.trimmingCharacters(in: .whitespaces)

        // Skip if we already discovered this printer
        if discoveredPrinters[trimmedName] != nil {
            return
        }

        // Use peripheral identifier as address (UUID string)
        let address = peripheral.identifier.uuidString

        // Store the peripheral for later connection
        discoveredPeripherals[address] = peripheral

        // Create printer data
        let printerData = BluetoothLePrinterData(
            name: trimmedName,
            address: address
        )

        // Add to discovered printers
        discoveredPrinters[trimmedName] = printerData

        debugPrint("Discovered Zebra printer: \(trimmedName) (\(address)), RSSI: \(RSSI)")

        // Notify Flutter about the discovered printer
        let printersList = Array(discoveredPrinters.values)
        flutterApi.onBluetoothLePrintersDetected(printerData: printersList) { result in
            if case .failure(let error) = result {
                debugPrint(
                    "Failed to notify Flutter about discovered printer: \(error.localizedDescription)"
                )
            }
        }
    }

    func printOverBluetoothLeWithoutParing(
        address: String, zpl: String, completion: @escaping (Result<Void, Error>) -> Void
    ) {
        debugPrint("printOverBluetoothLeWithoutParing: address=\(address), zpl length=\(zpl.count)")

        // Validate that we have an address
        guard !address.isEmpty else {
            let error = NSError(
                domain: "LinkOsMultiplatformSdk",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No printer address provided"]
            )
            completion(.failure(error))
            return
        }

        // Convert ZPL string to data
        guard let zplData = (zpl + "\r\n").data(using: .utf8) else {
            let error = NSError(
                domain: "LinkOsMultiplatformSdk",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert ZPL data to UTF-8"]
            )
            completion(.failure(error))
            return
        }

        // Store print data and completion
        printZplData = zplData
        printCompletion = completion
        targetAddress = address
        isConnectingDirectly = true

        // Ensure we have a central manager
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }

        guard let manager = centralManager else {
            let error = NSError(
                domain: "LinkOsMultiplatformSdk",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Bluetooth central manager not available"]
            )
            completion(.failure(error))
            return
        }

        // Check Bluetooth state
        guard manager.state == .poweredOn else {
            let error = NSError(
                domain: "LinkOsMultiplatformSdk",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Bluetooth is not powered on"]
            )
            completion(.failure(error))
            return
        }

        // First, check if we have the peripheral stored from previous scanning
        if let peripheral = discoveredPeripherals[address] {
            debugPrint("Using stored peripheral: \(peripheral.identifier.uuidString)")
            printPeripheral = peripheral
            peripheral.delegate = self
            manager.connect(peripheral, options: nil)
            return
        }

        // Try to retrieve from system using UUID (if address is a UUID)
        // This only works for peripherals that were previously connected
        if let uuid = UUID(uuidString: address) {
            let peripherals = manager.retrievePeripherals(withIdentifiers: [uuid])
            if let foundPeripheral = peripherals.first {
                debugPrint(
                    "Retrieved peripheral from system cache: \(foundPeripheral.identifier.uuidString)"
                )
                printPeripheral = foundPeripheral
                foundPeripheral.delegate = self
                manager.connect(foundPeripheral, options: nil)
                return
            } else {
                debugPrint("Peripheral not found in system cache, will scan for UUID: \(address)")
            }
        }

        // If we have a UUID but it's not in the system cache, or if it's a MAC address,
        // we need to scan to find the device
        // Start scanning to find the device (without RSSI filtering for direct connection)
        let addressType = UUID(uuidString: address) != nil ? "UUID" : "MAC address"
        debugPrint(
            "Starting scan to find Zebra printer (direct connection mode, \(addressType)): \(address)"
        )
        manager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Set a timeout for scanning (15 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            if self.isConnectingDirectly, self.printPeripheral == nil {
                // Stop scanning
                manager.stopScan()
                self.isConnectingDirectly = false

                let error = NSError(
                    domain: "LinkOsMultiplatformSdk",
                    code: 7,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Printer not found. Please ensure the printer is powered on, in range, and Bluetooth is enabled."
                    ]
                )
                if let completion = self.printCompletion {
                    self.printCompletion = nil
                    completion(.failure(error))
                }
                self.cleanupPrintState()
            }
        }
    }

    // MARK: - CBPeripheralDelegate for printing

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debugPrint("Connected to peripheral: \(peripheral.identifier.uuidString)")

        // Stop scanning if we're scanning
        if isScanning {
            central.stopScan()
            isScanning = false
        }

        // Stop scanning if we were connecting directly
        if isConnectingDirectly {
            central.stopScan()
            isConnectingDirectly = false
        }

        // Discover services
        peripheral.discoverServices([ZPRINTER_SERVICE_UUID])
    }

    func centralManager(
        _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
    ) {
        debugPrint(
            "Failed to connect to peripheral: \(error?.localizedDescription ?? "Unknown error")")

        let nsError =
            error
            ?? NSError(
                domain: "LinkOsMultiplatformSdk",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Failed to connect to printer"]
            )

        if let completion = printCompletion {
            printCompletion = nil
            completion(.failure(nsError))
        }

        cleanupPrintState()
    }

    func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
    ) {
        debugPrint("Disconnected from peripheral: \(error?.localizedDescription ?? "No error")")
        cleanupPrintState()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            debugPrint("Error discovering services: \(error.localizedDescription)")
            if let completion = printCompletion {
                printCompletion = nil
                completion(.failure(error))
            }
            cleanupPrintState()
            return
        }

        guard let services = peripheral.services else {
            let error = NSError(
                domain: "LinkOsMultiplatformSdk",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: "No services found on printer"]
            )
            if let completion = printCompletion {
                printCompletion = nil
                completion(.failure(error))
            }
            cleanupPrintState()
            return
        }

        // Find the Zebra printer service
        for service in services {
            if service.uuid == ZPRINTER_SERVICE_UUID {
                debugPrint("Found Zebra printer service, discovering characteristics...")
                peripheral.discoverCharacteristics(
                    [
                        WRITE_TO_ZPRINTER_CHARACTERISTIC_UUID,
                        READ_FROM_ZPRINTER_CHARACTERISTIC_UUID,
                    ], for: service)
                return
            }
        }

        // Service not found
        let error = NSError(
            domain: "LinkOsMultiplatformSdk",
            code: 9,
            userInfo: [NSLocalizedDescriptionKey: "Zebra printer service not found"]
        )
        if let completion = printCompletion {
            printCompletion = nil
            completion(.failure(error))
        }
        cleanupPrintState()
    }

    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        if let error = error {
            debugPrint("Error discovering characteristics: \(error.localizedDescription)")
            if let completion = printCompletion {
                printCompletion = nil
                completion(.failure(error))
            }
            cleanupPrintState()
            return
        }

        guard let characteristics = service.characteristics else {
            let error = NSError(
                domain: "LinkOsMultiplatformSdk",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "No characteristics found"]
            )
            if let completion = printCompletion {
                printCompletion = nil
                completion(.failure(error))
            }
            cleanupPrintState()
            return
        }

        // Find the write characteristic
        for characteristic in characteristics {
            if characteristic.uuid == WRITE_TO_ZPRINTER_CHARACTERISTIC_UUID {
                writeCharacteristic = characteristic
                debugPrint("Found write characteristic, sending ZPL data...")

                // Write ZPL data to the characteristic
                if let zplData = printZplData {
                    peripheral.writeValue(zplData, for: characteristic, type: .withResponse)
                } else {
                    let error = NSError(
                        domain: "LinkOsMultiplatformSdk",
                        code: 11,
                        userInfo: [NSLocalizedDescriptionKey: "ZPL data not available"]
                    )
                    if let completion = printCompletion {
                        printCompletion = nil
                        completion(.failure(error))
                    }
                    cleanupPrintState()
                }
                return
            }
        }

        // Write characteristic not found
        let error = NSError(
            domain: "LinkOsMultiplatformSdk",
            code: 12,
            userInfo: [NSLocalizedDescriptionKey: "Write characteristic not found"]
        )
        if let completion = printCompletion {
            printCompletion = nil
            completion(.failure(error))
        }
        cleanupPrintState()
    }

    func peripheral(
        _ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?
    ) {
        if let error = error {
            debugPrint("Error writing to characteristic: \(error.localizedDescription)")
            if let completion = printCompletion {
                printCompletion = nil
                completion(.failure(error))
            }
        } else {
            debugPrint("Successfully wrote ZPL data to printer")
            // Wait a bit to ensure data is sent
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let completion = self.printCompletion {
                    self.printCompletion = nil
                    completion(.success(()))
                }
                self.cleanupPrintState()
            }
            return
        }

        cleanupPrintState()
    }

    private func cleanupPrintState() {
        if let peripheral = printPeripheral, let manager = centralManager {
            if peripheral.state == .connected {
                manager.cancelPeripheralConnection(peripheral)
            }
        }
        printPeripheral = nil
        writeCharacteristic = nil
        printZplData = nil
        targetAddress = nil
        isConnectingDirectly = false
    }

    func requestLocationEnable(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success((true)))
    }
}
