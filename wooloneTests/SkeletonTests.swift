//
//  SkeletonTests.swift
//  wooloneTests
//
//  Created by Fikrah Damar Huda on 28/08/26.
//

import CoreGraphics
import Testing
import Vision
@testable import woolone

struct SkeletonTests {
    @Test func everyChainIsOrderedAndAtLeastTwoJointsLong() {
        for chain in Skeleton.chains {
            #expect(chain.count >= 2)
            #expect(Set(chain).count == chain.count)
        }
    }

    @Test func aFullyVisibleBodyDrawsEveryChain() {
        let frame = frame(confidence: 0.9)
        #expect(frame.chains(above: PoseConfidence.draw).count == Skeleton.chains.count)
    }

    /// A shortened arm draws shoulder straight to wrist, which reads as a pose rather than a gap.
    @Test func oneWeakJointDropsItsWholeChain() {
        var joints = Self.body(confidence: 0.9)
        joints[.leftElbow] = woolone.Joint(name: .leftElbow, position: .zero, confidence: 0.2)
        let frame = Self.frame(joints)

        let chains = frame.chains(above: PoseConfidence.draw)
        #expect(chains.count == Skeleton.chains.count - 1)
        #expect(!chains.contains { $0.contains { $0.name == .leftWrist } })
    }

    @Test func aMissingJointDropsItsWholeChain() {
        var joints = Self.body(confidence: 0.9)
        joints[.rightAnkle] = nil
        let frame = Self.frame(joints)

        #expect(frame.chains(above: PoseConfidence.draw).count == Skeleton.chains.count - 1)
    }

    // MARK: - Fixtures

    private func frame(confidence: Float) -> PoseFrame {
        Self.frame(Self.body(confidence: confidence))
    }

    private static func frame(
        _ joints: [HumanBodyPoseObservation.JointName: woolone.Joint]
    ) -> PoseFrame {
        PoseFrame(
            joints: joints,
            observationConfidence: 1,
            imageSize: CGSize(width: 720, height: 1280),
            orientation: .right,
            supportedJointCount: 19,
            inferenceMilliseconds: 18
        )
    }

    private static func body(
        confidence: Float
    ) -> [HumanBodyPoseObservation.JointName: woolone.Joint] {
        var joints: [HumanBodyPoseObservation.JointName: woolone.Joint] = [:]
        var y: CGFloat = 100
        for names in Skeleton.chains {
            for name in names where joints[name] == nil {
                joints[name] = woolone.Joint(
                    name: name,
                    position: CGPoint(x: 360, y: y),
                    confidence: confidence
                )
                y += 40
            }
        }
        return joints
    }
}
