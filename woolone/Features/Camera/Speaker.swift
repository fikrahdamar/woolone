//
//  Speaker.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 04/09/26.
//

import AVFoundation
import Foundation

/// Says a cue out loud. Knows nothing about why — SpeechCoach decides that.
@MainActor
final class Speaker {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "en-US")
    private var isConfigured = false

    func say(_ cue: SpeechCoach.Cue) {
        configureOnce()
        // a cue arriving while another is still being spoken is dropped, never queued. Speech takes
        // about a second; a queue would deliver "up" after the rep is over. Same rule as
        // alwaysDiscardsLateVideoFrames — a late cue is worse than silence
        guard !synthesizer.isSpeaking else { return }

        let utterance = AVSpeechUtterance(string: cue.phrase)
        utterance.voice = voice
        // slightly quick: these are one and two-word cues delivered mid-movement
        utterance.rate = 0.54
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // .playback so a cue is heard with the silent switch on — a coach the phone can mute is not a
    // coach. mixWithOthers leaves the user's music playing, ducked while a cue speaks
    private func configureOnce() {
        guard !isConfigured else { return }
        isConfigured = true
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .voicePrompt,
            options: [.mixWithOthers, .duckOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
