//
//  ImageOrientationTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 25/08/26.
//

import CoreGraphics
import ImageIO
import Testing
@testable import woolone

struct ImageOrientationTests {
    @Test(arguments: [
        CGImagePropertyOrientation.left,
        .leftMirrored,
        .right,
        .rightMirrored
    ])
    func quarterTurnsSwapTheAxes(orientation: CGImagePropertyOrientation) {
        #expect(orientation.swapsAxes)
    }

    @Test(arguments: [
        CGImagePropertyOrientation.up,
        .upMirrored,
        .down,
        .downMirrored
    ])
    func halfTurnsAndMirrorsLeaveTheAxesAlone(orientation: CGImagePropertyOrientation) {
        #expect(!orientation.swapsAxes)
    }

    // the shape the detector relies on: a landscape buffer becomes a portrait image, or every joint transposes
    @Test func aLandscapeBufferReadsAsPortraitUnderTheCameraOrientations() {
        let buffer = CGSize(width: 1280, height: 720)
        for orientation in [CGImagePropertyOrientation.right, .leftMirrored] {
            #expect(orientedSize(buffer, orientation) == CGSize(width: 720, height: 1280))
        }
    }

    @Test func anUprightBufferKeepsItsSize() {
        let buffer = CGSize(width: 1280, height: 720)
        #expect(orientedSize(buffer, .up) == buffer)
    }

    private func orientedSize(
        _ size: CGSize,
        _ orientation: CGImagePropertyOrientation
    ) -> CGSize {
        orientation.swapsAxes ? CGSize(width: size.height, height: size.width) : size
    }
}
