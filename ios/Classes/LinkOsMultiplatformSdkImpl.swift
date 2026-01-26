//
//  LinkOsMultiplatformSdkImpl.swift
//  link_os_multiplatform_sdk
//
//  Created by Ali Abbas on 17/01/2026.
//

import CoreBluetooth
import Foundation
import ExternalAccessory

class LinkOsMultiplatformSdkHostApiImpl: NSObject, LinkOsMultiplatformSdkHostApi,
    CBCentralManagerDelegate
{

    private let flutterApi: LinkOsMultiplatformSdkFlutterApi
    private var bluetoothPermissionCompletion: ((Result<Bool, Error>) -> Void)?
    private var bluetoothStateCompletion: ((Result<Bool, Error>) -> Void)?
    private var centralManager: CBCentralManager?
    private var bluetoothStateManager: CBCentralManager?
    private var scanningCompletion: ((Result<Void, Error>) -> Void)?
    private var discoveredPrinters: [String: BluetoothLePrinterData] = [:]
    private var isScanning: Bool = false

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
                userInfo: [NSLocalizedDescriptionKey: "Failed to initialize Bluetooth central manager"]
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
                userInfo: [NSLocalizedDescriptionKey: "Bluetooth is not available or not powered on"]
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
                debugPrint("Failed to notify Flutter about discovered printer: \(error.localizedDescription)")
            }
        }
    }

    func printOverBluetoothLeWithoutParing(
        address: String, zpl: String, completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let printQueue = DispatchQueue(label: "com.link_os_multiplatform_sdk.print_queue")
        
        printQueue.async {
            // Register for local notifications to detect accessories
            EAAccessoryManager.shared().registerForLocalNotifications()
            
            debugPrint("printOverBluetoothLeWithoutParing: address=\(address), zpl length=\(zpl.count)")
                        
            // Validate that we have a mac address
            guard !address.isEmpty else {
                let error = NSError(
                    domain: "LinkOsMultiplatformSdk",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No printer found. Please provide a valid MAC address or ensure a Zebra printer is connected."]
                )
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // Create connection using MfiBtPrinterConnection
            // The Objective-C initializer returns 'id' which Swift bridges as optional MfiBtPrinterConnection?
            guard let conn = MfiBtPrinterConnection(serialNumber: address) else {
                let error = NSError(
                    domain: "LinkOsMultiplatformSdk",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create printer connection"]
                )
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            debugPrint("Connection created successfully: \(conn)")
            
            // Open the connection
            let openSuccess = conn.open()
            guard openSuccess else {
                let error = NSError(
                    domain: "LinkOsMultiplatformSdk",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to open printer connection"]
                )
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // Convert ZPL string to data
            guard let zplData = zpl.data(using: .utf8) else {
                conn.close()
                let error = NSError(
                    domain: "LinkOsMultiplatformSdk",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to convert ZPL data to UTF-8"]
                )
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // Write data to printer
            var writeError: NSError?
            let writeSuccess = conn.write(zplData, error: &writeError)
            
            // Wait a bit to ensure data is sent
            Thread.sleep(forTimeInterval: 1.0)
            
            debugPrint("Write success: \(writeSuccess), error: \(String(describing: writeError))")
            
            // Close the connection
            conn.close()
            
            // Check if write was successful
            if writeSuccess != -1 && writeError == nil {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } else {
                let error = writeError ?? NSError(
                    domain: "LinkOsMultiplatformSdk",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to write data to printer"]
                )
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func requestLocationEnable(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success((true)))
    }
}
