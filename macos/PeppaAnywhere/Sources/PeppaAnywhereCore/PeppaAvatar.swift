import Foundation

public struct PeppaAvatarPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum PeppaAvatarSurfaceType: String, Codable, Sendable {
    case sphere
    case ellipsoid
    case roundedRectangle
}

public struct PeppaAvatarSurface: Codable, Equatable, Sendable {
    public var type: PeppaAvatarSurfaceType
    public var width: Double
    public var height: Double
    public var depth: Double
    public var roundness: Double

    public init(type: PeppaAvatarSurfaceType, width: Double = 240, height: Double = 240, depth: Double = 240, roundness: Double = 1) {
        self.type = type
        self.width = width
        self.height = height
        self.depth = depth
        self.roundness = roundness
    }
}

public struct PeppaAvatarBodyNode: Codable, Equatable, Sendable {
    public var id: String?
    public var surface: PeppaAvatarSurface?

    public init(id: String? = nil, surface: PeppaAvatarSurface? = nil) {
        self.id = id
        self.surface = surface
    }
}

public struct PeppaAvatarBody: Codable, Equatable, Sendable {
    public var primary: PeppaAvatarSurface
    public var nodes: [PeppaAvatarBodyNode]

    public static let sphere = PeppaAvatarBody(primary: PeppaAvatarSurface(type: .sphere), nodes: [])

    public init(primary: PeppaAvatarSurface, nodes: [PeppaAvatarBodyNode]) {
        self.primary = primary
        self.nodes = nodes
    }
}

public struct PeppaAvatarColors: Codable, Equatable, Sendable {
    public var body: String
    public var eyes: String

    public init(body: String, eyes: String) {
        self.body = body
        self.eyes = eyes
    }
}

public struct PeppaAvatarHead: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct PeppaAvatarEye: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double
    public var x: Double
    public var y: Double
    public var angle: Double

    public init(width: Double, height: Double, x: Double, y: Double, angle: Double) {
        self.width = width
        self.height = height
        self.x = x
        self.y = y
        self.angle = angle
    }
}

public struct PeppaAvatarEyes: Codable, Equatable, Sendable {
    public var left: PeppaAvatarEye
    public var right: PeppaAvatarEye
    public var spacing: Double

    public init(left: PeppaAvatarEye, right: PeppaAvatarEye, spacing: Double) {
        self.left = left
        self.right = right
        self.spacing = spacing
    }
}

public struct PeppaAvatarMotion: Codable, Equatable, Sendable {
    public var eyes: String
    public var body: String

    public init(eyes: String, body: String) {
        self.eyes = eyes
        self.body = body
    }
}

public struct PeppaAvatarExpressionColors: Codable, Equatable, Sendable {
    public var body: String?
    public var eyes: String?

    public init(body: String? = nil, eyes: String? = nil) {
        self.body = body
        self.eyes = eyes
    }
}

public struct PeppaAvatarExpression: Codable, Equatable, Sendable {
    public var head: PeppaAvatarHead
    public var eyes: PeppaAvatarEyes
    public var perspective: Double
    public var motion: PeppaAvatarMotion
    public var colors: PeppaAvatarExpressionColors?

    public init(head: PeppaAvatarHead, eyes: PeppaAvatarEyes, perspective: Double, motion: PeppaAvatarMotion, colors: PeppaAvatarExpressionColors? = nil) {
        self.head = head
        self.eyes = eyes
        self.perspective = perspective
        self.motion = motion
        self.colors = colors
    }
}

public struct PeppaAvatarAnimationStep: Codable, Equatable, Sendable {
    public var expression: String
    public var holdMs: Double
    public var transitionMs: Double
    public var transition: String

    public init(expression: String, holdMs: Double, transitionMs: Double, transition: String) {
        self.expression = expression
        self.holdMs = holdMs
        self.transitionMs = transitionMs
        self.transition = transition
    }
}

public struct PeppaAvatarBlink: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var initialDelayMs: Double
    public var minIntervalMs: Double
    public var maxIntervalMs: Double
    public var durationMs: Double
}

public struct PeppaAvatarAnimationMetadata: Codable, Equatable, Sendable {
    public var label: String?
    public var description: String?
    public var group: String?
}

public struct PeppaAvatarAnimation: Codable, Equatable, Sendable {
    public var playbackMode: String
    public var steps: [PeppaAvatarAnimationStep]
    public var blink: PeppaAvatarBlink?
    public var metadata: PeppaAvatarAnimationMetadata?

    public init(playbackMode: String = "loop", steps: [PeppaAvatarAnimationStep], blink: PeppaAvatarBlink? = nil, metadata: PeppaAvatarAnimationMetadata? = nil) {
        self.playbackMode = playbackMode
        self.steps = steps
        self.blink = blink
        self.metadata = metadata
    }
}

public struct PeppaAvatarDefinition: Codable, Equatable, Sendable {
    public var name: String
    public var body: PeppaAvatarBody
    public var colors: PeppaAvatarColors
    public var expressions: [String: PeppaAvatarExpression]
    public var expressionOrder: [String]
    public var animations: [String: PeppaAvatarAnimation]
    public var animationOrder: [String]

    public init(name: String, body: PeppaAvatarBody, colors: PeppaAvatarColors, expressions: [String: PeppaAvatarExpression], expressionOrder: [String], animations: [String: PeppaAvatarAnimation], animationOrder: [String]) {
        self.name = name
        self.body = body
        self.colors = colors
        self.expressions = expressions
        self.expressionOrder = expressionOrder
        self.animations = animations
        self.animationOrder = animationOrder
    }

    public static func decode(data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}

public struct PeppaAvatarFrame: Equatable, Sendable {
    public var head: [PeppaAvatarPoint]
    public var leftEye: [PeppaAvatarPoint]
    public var rightEye: [PeppaAvatarPoint]
    public var bodyColor: String
    public var eyeColor: String

    public init(head: [PeppaAvatarPoint], leftEye: [PeppaAvatarPoint], rightEye: [PeppaAvatarPoint], bodyColor: String, eyeColor: String) {
        self.head = head
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.bodyColor = bodyColor
        self.eyeColor = eyeColor
    }
}

private struct PeppaQuaternion {
    var w: Double
    var x: Double
    var y: Double
    var z: Double

    static let identity = PeppaQuaternion(w: 1, x: 0, y: 0, z: 0)

    func normalized() -> Self {
        let length = max(0.000001, sqrt(w * w + x * x + y * y + z * z))
        return Self(w: w / length, x: x / length, y: y / length, z: z / length)
    }

    static func * (lhs: Self, rhs: Self) -> Self {
        Self(
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
            z: lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w
        ).normalized()
    }

    static func fromAxis(_ axis: (Double, Double, Double), radians: Double) -> Self {
        let half = radians / 2
        let sine = sin(half)
        return Self(w: cos(half), x: axis.0 * sine, y: axis.1 * sine, z: axis.2 * sine).normalized()
    }

    static func fromEuler(x: Double, y: Double, z: Double) -> Self {
        let xRotation = fromAxis((1, 0, 0), radians: x)
        let yRotation = fromAxis((0, 1, 0), radians: y)
        let zRotation = fromAxis((0, 0, 1), radians: z)
        return (zRotation * xRotation * yRotation).normalized()
    }

    func rotate(_ point: (Double, Double, Double)) -> (Double, Double, Double) {
        let q = self
        let t = (
            2 * (q.y * point.2 - q.z * point.1),
            2 * (q.z * point.0 - q.x * point.2),
            2 * (q.x * point.1 - q.y * point.0)
        )
        return (
            point.0 + q.w * t.0 + q.y * t.2 - q.z * t.1,
            point.1 + q.w * t.1 + q.z * t.0 - q.x * t.2,
            point.2 + q.w * t.2 + q.x * t.1 - q.y * t.0
        )
    }
}

public struct PeppaAvatarRenderer: Sendable {
    public let definition: PeppaAvatarDefinition
    private static let radius = 120.0
    private static let focalLength = 620.0

    public init(definition: PeppaAvatarDefinition) {
        self.definition = definition
    }

    public func scaleToFit(width: Double, height: Double, padding: Double = 8) -> Double {
        let bodyWidth = max(1, definition.body.primary.width)
        let bodyHeight = max(1, definition.body.primary.height)
        return min(1, max(0.01, min((width - padding * 2) / bodyWidth, (height - padding * 2) / bodyHeight)))
    }

    public func frame(animationKey: String, elapsed: TimeInterval) -> PeppaAvatarFrame {
        let expression = expression(for: animationKey, elapsed: max(0, elapsed))
        let orientation = PeppaQuaternion.fromEuler(
            x: expression.head.x * .pi / 180,
            y: expression.head.y * .pi / 180,
            z: expression.head.z * .pi / 180
        )
        let head = spherePath(orientation: orientation, perspective: expression.perspective)
        let left = eyePath(expression.eyes.left, side: -1, spacing: expression.eyes.spacing, orientation: orientation, perspective: expression.perspective)
        let right = eyePath(expression.eyes.right, side: 1, spacing: expression.eyes.spacing, orientation: orientation, perspective: expression.perspective)
        return PeppaAvatarFrame(
            head: head,
            leftEye: left,
            rightEye: right,
            bodyColor: expression.colors?.body ?? definition.colors.body,
            eyeColor: expression.colors?.eyes ?? definition.colors.eyes
        )
    }

    private func expression(for animationKey: String, elapsed: TimeInterval) -> PeppaAvatarExpression {
        guard let animation = definition.animations[animationKey], !animation.steps.isEmpty else {
            return definition.expressions[definition.expressionOrder.first ?? ""] ?? fallbackExpression
        }
        let total = animation.steps.reduce(0) { $0 + max(0, $1.holdMs) + max(0, $1.transitionMs) }
        guard total > 0 else { return definition.expressions[animation.steps[0].expression] ?? fallbackExpression }
        var time = elapsed * 1000
        if animation.playbackMode == "loop" || animation.playbackMode.isEmpty {
            time = time.truncatingRemainder(dividingBy: total)
        } else {
            time = min(time, total)
        }
        var cursor = 0.0
        for index in animation.steps.indices {
            let step = animation.steps[index]
            let holdEnd = cursor + max(0, step.holdMs)
            let transitionEnd = holdEnd + max(0, step.transitionMs)
            if time <= holdEnd || index == animation.steps.index(before: animation.steps.endIndex) {
                return definition.expressions[step.expression] ?? fallbackExpression
            }
            if time < transitionEnd {
                let nextIndex = animation.steps.index(after: index) == animation.steps.endIndex ? 0 : animation.steps.index(after: index)
                let next = animation.steps[nextIndex]
                let progress = easing((time - holdEnd) / max(1, step.transitionMs), name: step.transition)
                return interpolate(
                    definition.expressions[step.expression] ?? fallbackExpression,
                    definition.expressions[next.expression] ?? fallbackExpression,
                    amount: progress
                )
            }
            cursor = transitionEnd
        }
        return definition.expressions[animation.steps.last!.expression] ?? fallbackExpression
    }

    private var fallbackExpression: PeppaAvatarExpression {
        PeppaAvatarExpression(
            head: PeppaAvatarHead(x: 0, y: 0, z: 0),
            eyes: PeppaAvatarEyes(
                left: PeppaAvatarEye(width: 20, height: 50, x: 0, y: -7, angle: 0),
                right: PeppaAvatarEye(width: 20, height: 50, x: 0, y: -7, angle: 0),
                spacing: 35
            ),
            perspective: 1,
            motion: PeppaAvatarMotion(eyes: "none", body: "none")
        )
    }

    private func interpolate(_ a: PeppaAvatarExpression, _ b: PeppaAvatarExpression, amount t: Double) -> PeppaAvatarExpression {
        func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        return PeppaAvatarExpression(
            head: PeppaAvatarHead(x: mix(a.head.x, b.head.x), y: mix(a.head.y, b.head.y), z: mix(a.head.z, b.head.z)),
            eyes: PeppaAvatarEyes(
                left: PeppaAvatarEye(width: mix(a.eyes.left.width, b.eyes.left.width), height: mix(a.eyes.left.height, b.eyes.left.height), x: mix(a.eyes.left.x, b.eyes.left.x), y: mix(a.eyes.left.y, b.eyes.left.y), angle: mix(a.eyes.left.angle, b.eyes.left.angle)),
                right: PeppaAvatarEye(width: mix(a.eyes.right.width, b.eyes.right.width), height: mix(a.eyes.right.height, b.eyes.right.height), x: mix(a.eyes.right.x, b.eyes.right.x), y: mix(a.eyes.right.y, b.eyes.right.y), angle: mix(a.eyes.right.angle, b.eyes.right.angle)),
                spacing: mix(a.eyes.spacing, b.eyes.spacing)
            ),
            perspective: mix(a.perspective, b.perspective),
            motion: a.motion,
            colors: t < 0.5 ? a.colors : b.colors
        )
    }

    private func easing(_ value: Double, name: String) -> Double {
        let t = min(1, max(0, value))
        switch name {
        case "linear": return t
        case "ease-in": return t * t
        case "ease-out": return 1 - (1 - t) * (1 - t)
        default: return t * t * (3 - 2 * t)
        }
    }

    private func project(_ point: (Double, Double, Double), perspective: Double) -> PeppaAvatarPoint {
        let denominator = max(1, Self.focalLength - point.2 * perspective)
        let scale = Self.focalLength / denominator
        return PeppaAvatarPoint(x: point.0 * scale, y: point.1 * scale)
    }

    private func spherePath(orientation: PeppaQuaternion, perspective: Double) -> [PeppaAvatarPoint] {
        (0..<96).map { index in
            let angle = Double(index) / 96 * 2 * .pi
            let local = (Self.radius * cos(angle), Self.radius * sin(angle), 0.0)
            return project(orientation.rotate(local), perspective: perspective)
        }
    }

    private func eyePath(_ eye: PeppaAvatarEye, side: Double, spacing: Double, orientation: PeppaQuaternion, perspective: Double) -> [PeppaAvatarPoint] {
        let halfWidth = max(0.5, eye.width / 2)
        let halfHeight = max(0.5, eye.height / 2)
        let center = (side * spacing / 2 + eye.x, eye.y)
        let samples = 20
        return (0..<samples).map { index in
            let angle = Double(index) / Double(samples) * 2 * .pi
            let point = (center.0 + halfWidth * cos(angle), center.1 + halfHeight * sin(angle), sqrt(max(0, Self.radius * Self.radius - min(Self.radius * Self.radius, pow(center.0 + halfWidth * cos(angle), 2) + pow(center.1 + halfHeight * sin(angle), 2)))) )
            let rotated = orientation.rotate(point)
            let projected = project(rotated, perspective: perspective)
            let rotation = eye.angle * .pi / 180
            return PeppaAvatarPoint(x: projected.x * cos(rotation) - projected.y * sin(rotation), y: projected.x * sin(rotation) + projected.y * cos(rotation))
        }
    }
}
