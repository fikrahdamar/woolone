//
//  CameraPermission.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import AVFoundation

nonisolated enum CameraPermission {
    enum Status: Sendable, Equatable {
        case authorized
        case denied
        case restricted
    }

    static func request() async -> Status {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        @unknown default:
            return .denied
        }
    }
}
