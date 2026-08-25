//
//  AspectFill.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import CoreGraphics

/// Maps image pixels onto a .resizeAspectFill preview — the overlay is wrong by exactly the crop without it.
nonisolated struct AspectFill: Equatable {
    let scale: CGFloat
    let offset: CGPoint

    init(imageSize: CGSize, viewSize: CGSize) {
        guard imageSize.width > 0, imageSize.height > 0 else {
            scale = 1
            offset = .zero
            return
        }
        scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        offset = CGPoint(
            x: (viewSize.width - imageSize.width * scale) / 2,
            y: (viewSize.height - imageSize.height * scale) / 2
        )
    }

    func point(_ imagePoint: CGPoint) -> CGPoint {
        CGPoint(x: imagePoint.x * scale + offset.x, y: imagePoint.y * scale + offset.y)
    }
}
