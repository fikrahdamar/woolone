//
//  PoseOverlayView.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import SwiftUI

/// Dots on the joints — a wrong pixel conversion is invisible in a number and obvious here.
struct PoseOverlayView: View {
    let joints: [Joint]
    let chain: [Joint]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            if !joints.isEmpty {
                let fill = AspectFill(imageSize: imageSize, viewSize: geometry.size)
                // the chain is ordered hip → knee → ankle, so the line and the angle share one truth
                Path { path in
                    guard let first = chain.first else { return }
                    path.move(to: fill.point(first.position))
                    for joint in chain.dropFirst() {
                        path.addLine(to: fill.point(joint.position))
                    }
                }
                .stroke(.green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                ForEach(joints, id: \.name) { joint in
                    Circle()
                        .fill(colour(for: joint.confidence))
                        .frame(width: 14, height: 14)
                        .position(fill.point(joint.position))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // the band comes from Core; the View only decides what each band looks like
    private func colour(for confidence: Float) -> Color {
        switch ConfidenceBand(confidence) {
        case .drawable: .green
        case .judgeableOnly: .yellow
        case .unusable: .red
        }
    }
}

#Preview {
    PoseOverlayView(joints: [], chain: [], imageSize: .zero)
        .background(.black)
}
