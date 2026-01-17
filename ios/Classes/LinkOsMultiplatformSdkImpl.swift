//
//  LinkOsMultiplatformSdkImpl.swift
//  link_os_multiplatform_sdk
//
//  Created by Ali Abbas on 17/01/2026.
//

import Foundation

class LinkOsMultiplatformSdkHostApiImpl: LinkOsMultiplatformSdkHostApi {
    
    func isBluetoothEnabled() throws -> Bool {
        return true
    }
    
    func isLocationEnabled() throws -> Bool {
        return true
    }
    
    private let flutterApi: LinkOsMultiplatformSdkFlutterApi

    init(flutterApi: LinkOsMultiplatformSdkFlutterApi) {
        self.flutterApi = flutterApi
    }

    func requestBluetoothLePermissions(completion: @escaping (Result<Bool, Error>) -> Void) {

        completion(.success((true)))
    }

    func startBluetoothLeScanning(completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func printOverBluetoothLeWithoutParing(
        address: String, zpl: String, completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }

    func isBluetoothEnabled(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success((true)))
    }

    func requestBluetoothEnable(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success((true)))
    }

    func isLocationEnabled(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success((true)))
    }

    func requestLocationEnable(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success((true)))
    }

}
