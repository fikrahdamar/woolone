//
//  CaptureHUDView.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 24/08/26.
//

import SwiftUI

struct CaptureHUDView: View {
    let stats: CaptureStats
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "%.1f fps", stats.framesPerSecond))
                .font(.system(.title2, design: .monospaced, weight: .semibold))
            Text("frames \(stats.deliveredFrames) · dropped \(stats.droppedFrames)")
            Text(stats.delegateOnMainThread ? "delegate ON MAIN QUEUE" : "delegate off main queue")
                .foregroundStyle(stats.delegateOnMainThread ? .red : .green)
            Text(status)
                .foregroundStyle(.secondary)
        }
        .font(.system(.footnote, design: .monospaced))
        .padding(12)
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    CaptureHUDView(
        stats: CaptureStats(
            framesPerSecond: 29.9,
            deliveredFrames: 897,
            droppedFrames: 0,
            delegateOnMainThread: false
        ),
        status: "running"
    )
}
