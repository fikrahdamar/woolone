//
//  PoseSource.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import Foundation

/// The seam the ViewModel sees: live camera and JSON replay are indistinguishable behind it.
nonisolated protocol PoseSource: Sendable {
    var poseFrames: AsyncStream<PoseFrame> { get }
    var poseStats: AsyncStream<PoseStats> { get }
    func start() async throws
    func stop() async
    func use(_ facing: CameraFacing) async throws
}

extension PoseSource {
    // a recorded session has no camera to flip
    func use(_ facing: CameraFacing) async throws {}
}
