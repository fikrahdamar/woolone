//
//  PoseOverlayView.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import SwiftUI

/// Three dots on hip, knee and ankle — a wrong pixel conversion is invisible in a number and obvious here.
struct PoseOverlayView: View {
    let joints: [Joint]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            if !joints.isEmpty {
                let fill = AspectFill(imageSize: imageSize, viewSize: geometry.size)
                ForEach(joints, id: \.name) { joint in
                    Circle()
                        .fill(.green)
                        .frame(width: 16, height: 16)
                        .position(fill.point(joint.position))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    PoseOverlayView(joints: [], imageSize: .zero)
        .background(.black)
}
