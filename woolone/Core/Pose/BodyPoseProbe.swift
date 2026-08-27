//
//  BodyPoseProbe.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 23/08/26.
//

import CoreGraphics
import Foundation
import ImageIO
import Vision

nonisolated struct BodyPoseProbe {
    static let imageName = "pose-test"
    static let imageExtension = "jpg"

    private let tag = "[pose-probe]"

    /// Prints the full joint dump and returns a one-line summary for the screen.
    // @concurrent, or approachable concurrency inherits the caller's actor and runs Vision on main
    @concurrent
    func run() async -> String {
        do {
            return try await probe()
        } catch let failure as Failure {
            print("\(tag) \(failure.description)")
            return failure.description
        } catch {
            print("\(tag) pose request failed: \(error)")
            return "pose request failed: \(error.localizedDescription)"
        }
    }

    private func probe() async throws -> String {
        let source = try loadBundledImage()

        var request = DetectHumanBodyPoseRequest()
        request.detectsHands = false

        let observations = try await request.perform(
            on: source.image,
            orientation: source.orientation
        )

        print("\(tag) image \(Self.imageName).\(Self.imageExtension)"
            + " \(Int(source.size.width))x\(Int(source.size.height))"
            + " orientation=\(source.orientation.rawValue)")
        print("\(tag) request supports \(request.supportedJointNames.count) joint names")
        print("\(tag) observations: \(observations.count)")

        guard let observation = observations.max(by: { $0.confidence < $1.confidence }) else {
            let message = "no person found in \(Self.imageName).\(Self.imageExtension)"
            print("\(tag) \(message)")
            return message
        }

        if observation.confidence < 0.6 {
            print("\(tag) WARNING observation confidence \(conf(observation.confidence)) is below the 0.6 gate")
        }
        print("\(tag) observation confidence \(conf(observation.confidence))")

        let joints = observation.allJoints()
        // supportedJointNames is the enum's own order — a missing joint shows as a gap, not a shorter list
        for name in request.supportedJointNames {
            print("\(tag) \(line(for: name, joint: joints[name], imageSize: source.size))")
        }

        let supported = request.supportedJointNames.count
        let summary = "\(joints.count)/\(supported) joints"
            + " · neck \(mark(joints[.neck] != nil)) root \(mark(joints[.root] != nil))"
            + " · observation \(conf(observation.confidence))"
        print("\(tag) \(summary)")
        return summary
    }

    private func line(
        for name: HumanBodyPoseObservation.JointName,
        joint: Vision.Joint?,
        imageSize: CGSize
    ) -> String {
        let label = name.rawValue.padding(toLength: 14, withPad: " ", startingAt: 0)
        guard let joint else { return "\(label) — not returned" }
        // pixels before any angle math — normalized x and y are scaled to width and height separately
        let pixel = joint.location.toImageCoordinates(imageSize, origin: .upperLeft)
        return "\(label)"
            + " norm(\(norm(joint.location.x)), \(norm(joint.location.y)))"
            + " px(\(px(pixel.x)), \(px(pixel.y)))"
            + " conf \(conf(joint.confidence))"
    }

    // MARK: - Image loading

    private struct ImageSource {
        let image: CGImage
        let size: CGSize
        let orientation: CGImagePropertyOrientation
    }

    private func loadBundledImage() throws -> ImageSource {
        guard let url = Bundle.main.url(
            forResource: Self.imageName,
            withExtension: Self.imageExtension
        ) else {
            throw Failure.imageMissing
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw Failure.imageUnreadable
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let raw = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: raw) ?? .up

        var size = CGSize(width: image.width, height: image.height)
        // Vision normalizes against the oriented image, so a quarter-turn EXIF tag swaps the axes
        if orientation.swapsAxes {
            size = CGSize(width: size.height, height: size.width)
        }
        return ImageSource(image: image, size: size, orientation: orientation)
    }

    // MARK: - Failure

    enum Failure: Error, CustomStringConvertible {
        case imageMissing
        case imageUnreadable

        var description: String {
            switch self {
            case .imageMissing:
                "\(BodyPoseProbe.imageName).\(BodyPoseProbe.imageExtension) is not in the app bundle — drop it into woolone/ and rebuild"
            case .imageUnreadable:
                "\(BodyPoseProbe.imageName).\(BodyPoseProbe.imageExtension) is in the bundle but could not be decoded"
            }
        }
    }

    // MARK: - Formatting

    private func conf(_ value: Float) -> String { String(format: "%.2f", value) }
    private func norm(_ value: CGFloat) -> String { String(format: "%.3f", value) }
    private func px(_ value: CGFloat) -> String { String(format: "%.1f", value) }
    private func mark(_ present: Bool) -> String { present ? "yes" : "MISSING" }
}
