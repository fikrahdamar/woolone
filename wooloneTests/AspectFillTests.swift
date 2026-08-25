//
//  AspectFillTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import CoreGraphics
import Testing
@testable import woolone

struct AspectFillTests {
    @Test func cropsTheTallerAxisWhenTheViewIsWider() {
        let fill = AspectFill(
            imageSize: CGSize(width: 720, height: 1280),
            viewSize: CGSize(width: 720, height: 640)
        )
        #expect(fill.scale == 1)
        #expect(fill.offset.y == -320)
        #expect(fill.point(CGPoint(x: 0, y: 640)) == CGPoint(x: 0, y: 320))
    }

    @Test func centreOfTheImageLandsAtTheCentreOfTheView() {
        let fill = AspectFill(
            imageSize: CGSize(width: 720, height: 1280),
            viewSize: CGSize(width: 390, height: 844)
        )
        let centre = fill.point(CGPoint(x: 360, y: 640))
        #expect(abs(centre.x - 195) < 0.001)
        #expect(abs(centre.y - 422) < 0.001)
    }

    @Test func degenerateImageSizeIsIdentity() {
        let fill = AspectFill(imageSize: .zero, viewSize: CGSize(width: 390, height: 844))
        #expect(fill.scale == 1)
        #expect(fill.offset == .zero)
    }
}
