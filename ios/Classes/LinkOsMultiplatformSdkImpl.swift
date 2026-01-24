//
//  LinkOsMultiplatformSdkImpl.swift
//  link_os_multiplatform_sdk
//
//  Created by Ali Abbas on 17/01/2026.
//

import CoreBluetooth
import Foundation

class LinkOsMultiplatformSdkHostApiImpl: NSObject, LinkOsMultiplatformSdkHostApi,
    CBCentralManagerDelegate
{

    private let flutterApi: LinkOsMultiplatformSdkFlutterApi
    private var bluetoothPermissionCompletion: ((Result<Bool, Error>) -> Void)?
    private var bluetoothStateCompletion: ((Result<Bool, Error>) -> Void)?
    private var centralManager: CBCentralManager?
    private var bluetoothStateManager: CBCentralManager?

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
        completion(.success(()))
    }

    func printOverBluetoothLeWithoutParing(
        address: String, zpl: String, completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }

    func requestLocationEnable(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success((true)))
    }
}
