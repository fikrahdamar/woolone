//
//  ContentView.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 19/08/26.
//

import SwiftUI

struct ContentView: View {
    private let probe = BodyPoseProbe()
    @State private var status = "not run yet"
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Pose probe")
                .font(.headline)
            Text(status)
                .font(.system(.footnote, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Run pose probe") {
                guard !isRunning else { return }
                isRunning = true
                Task {
                    status = await probe.run()
                    isRunning = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
