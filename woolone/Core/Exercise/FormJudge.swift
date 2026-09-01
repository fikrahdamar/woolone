//
//  FormJudge.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 01/09/26.
//

import CoreGraphics
import Foundation

/// Compares a measurement to a range and says what it saw. Knows nothing about squats.
nonisolated struct FormJudge: Sendable {
    let definition: ExerciseDefinition

    struct Judgement: Sendable, Equatable {
        let rep: Int
        let fault: String
        let measured: CGFloat
        let limit: CGFloat
        let passed: Bool
        let cue: String?

        /// Names the measurement and the range it needed, never a verdict on the person.
        var text: String {
            let head = String(format: "%@ %.0f° · needs under %.0f°", fault, measured, limit)
            guard let cue else { return head }
            return "\(head) — \(cue)"
        }
    }

    /// nil when the rep carried no usable angle, or when the camera was not square enough to grade.
    func judge(_ rep: RepCounter.Rep, isSquare: Bool) -> Judgement? {
        guard isSquare, let measured = rep.lowestAngle, let fault = definition.faults.first else {
            return nil
        }
        let passed = fault.validRange.contains(measured)
        return Judgement(
            rep: rep.index,
            fault: fault.name,
            measured: measured,
            limit: fault.validRange.upperBound,
            passed: passed,
            cue: passed ? nil : fault.cue
        )
    }
}
