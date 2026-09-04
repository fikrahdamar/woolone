//
//  FormJudgeTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation
import Testing
import Vision
@testable import woolone

struct FormJudgeTests {
    @Test func aDeepRepPasses() throws {
        let verdict = try #require(Self.judge(depth: 84))
        #expect(verdict.passed)
        #expect(verdict.cue == nil)
    }

    @Test func aShallowRepFailsAndSaysWhatItNeeded() throws {
        let verdict = try #require(Self.judge(depth: 118))
        #expect(verdict.passed == false)
        #expect(verdict.cue == "go deeper")
        #expect(verdict.text == "depth 118° · needs under 86° — go deeper")
    }

    /// The cue names the measurement, never the person. This is the whole reason for angles over ML.
    @Test func theCueCarriesTheNumberAndTheRange() throws {
        let verdict = try #require(Self.judge(depth: 118))
        #expect(verdict.text.contains("118"))
        #expect(verdict.text.contains("86"))
    }

    /// A crooked camera reads the angle 21–56° wrong. Counting survives that; grading must not pretend to.
    @Test func aCrookedCameraProducesNoJudgementAtAll() {
        #expect(Self.judge(depth: 118, isSquare: false) == nil)
    }

    @Test func aRepWithNoAngleIsNotJudged() {
        #expect(Self.judge(depth: nil) == nil)
    }

    /// Config only: swapping the definition changes the verdict without touching the engine.
    @Test func adifferentDefinitionChangesTheVerdictWithNoNewType() throws {
        let lenient = ExerciseDefinition(
            name: "quarter squat",
            plane: .sagittal,
            cameraView: .side,
            faults: [
                ExerciseDefinition.Fault(
                    name: "depth",
                    joints: [.leftHip, .leftKnee, .leftAnkle],
                    validRange: 0...130,
                    cue: "go deeper"
                )
            ],
            outOfScope: []
        )
        let rep = RepCounter.Rep(index: 1, lowestAngle: 118, seconds: 2)
        let verdict = try #require(FormJudge(definition: lenient).judge(rep, isSquare: true))
        #expect(verdict.passed)
    }

    @Test func theSquatWritesDownWhatItCannotSee() {
        #expect(ExerciseDefinition.squat.outOfScope.count >= 3)
        #expect(ExerciseDefinition.squat.faults.count == 1)
    }

    // MARK: - Fixtures

    private static func judge(depth: CGFloat?, isSquare: Bool = true) -> FormJudge.Judgement? {
        FormJudge(definition: .squat)
            .judge(RepCounter.Rep(index: 1, lowestAngle: depth, seconds: 2), isSquare: isSquare)
    }
}
