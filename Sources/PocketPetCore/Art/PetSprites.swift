// Procedural pixel art for the Hingeling.
//
// The creature is an original design: a squat, pebble-shaped bush sprite with
// two folded-leaf ears and a crease down its middle, like a little book that
// opens and closes. It grows wider with each life stage and gains a silver
// tuft as an elder. Faces and extras are layered on top for each mood.
//
// Everything is built from small string stamps so the art is reviewable in a
// diff, testable on Linux and needs no binary assets.

public enum PetPose: Equatable, Hashable, Sendable {
    /// A looping pose for a mood.
    case mood(Mood)
    /// A one-shot reaction to an action.
    case reaction(PetReaction)
    /// The half-fold stage routine.
    case stage
}

/// One-shot reactions to player actions.
public enum PetReaction: String, CaseIterable, Codable, Sendable {
    case feed
    case clean
    case play
}

public enum PetSprites {
    /// Frames for a pose at a life stage. Loops have 2 or more frames.
    public static func frames(for pose: PetPose, stage: LifeStage) -> [PixelFrame] {
        switch pose {
        case .mood(let mood): moodFrames(mood, stage: stage)
        case .reaction(let reaction): reactionFrames(reaction, stage: stage)
        case .stage: stageFrames(stage: stage)
        }
    }

    // MARK: - Body

    private struct BodyMetrics {
        let width: Int
        let height: Int
        var left: Int { (PixelFrame.size - width) / 2 }
        var top: Int { PixelFrame.size - 2 - height }
        var centre: Int { left + width / 2 }
        var eyeRow: Int { top + height / 3 }
    }

    private static func metrics(for stage: LifeStage) -> BodyMetrics {
        switch stage {
        case .newborn: BodyMetrics(width: 10, height: 8)
        case .young: BodyMetrics(width: 12, height: 10)
        case .grown: BodyMetrics(width: 16, height: 12)
        case .elder: BodyMetrics(width: 16, height: 11)
        }
    }

    /// The pebble body, ears, crease, belly and feet.
    static func body(stage: LifeStage, earsDown: Bool = false) -> PixelFrame {
        let m = metrics(for: stage)
        var f = PixelFrame()
        let r = Double(m.width) / 2
        let ry = Double(m.height) / 2
        let cx = Double(m.left) + r - 0.5
        let cy = Double(m.top) + ry - 0.5
        // A squashed superellipse reads as a pebble, not an egg: flat base, wide shoulders.
        for y in m.top..<(m.top + m.height) {
            for x in m.left..<(m.left + m.width) {
                let nx = abs(Double(x) - cx) / r
                let ny = abs(Double(y) - cy) / ry
                let v = nx * nx * nx + ny * ny * ny
                if v <= 1.0 { f[x, y] = .body }
            }
        }
        // Outline: any body pixel touching empty space.
        let filled = f
        for y in 0..<PixelFrame.size {
            for x in 0..<PixelFrame.size where filled[x, y] == .body {
                let edge = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { filled[x + $0.0, y + $0.1] == .clear }
                if edge { f[x, y] = .outline }
            }
        }
        // Highlight on the upper left shoulder.
        for y in (m.top + 1)...(m.top + 2) {
            for x in (m.left + 2)...(m.left + 3) where f[x, y] == .body { f[x, y] = .bodyLight }
        }
        // Sandstone belly, lower middle.
        let bellyTop = m.top + m.height / 2 + 1
        for y in bellyTop..<(m.top + m.height - 1) {
            for x in (m.centre - m.width / 4)...(m.centre + m.width / 4 - 1) where f[x, y] == .body {
                f[x, y] = .belly
            }
        }
        // The hinge crease down the middle of the belly.
        for y in bellyTop..<(m.top + m.height - 1) where f[m.centre, y] == .belly { f[m.centre, y] = .crease }
        // Folded-leaf ears.
        let leftEar = earsDown ? ["oo.", "obo", ".oo"] : [".o", "ob", "olo"]
        let rightEar = earsDown ? [".oo", "obo", "oo."] : ["o.", "bo", "olo"]
        f.stamp(leftEar, x: m.left + 1, y: m.top - (earsDown ? 1 : 2))
        f.stamp(rightEar, x: m.left + m.width - (earsDown ? 4 : 4), y: m.top - (earsDown ? 1 : 2))
        // Feet.
        f.stamp(["oo"], x: m.left + 2, y: m.top + m.height)
        f.stamp(["oo"], x: m.left + m.width - 4, y: m.top + m.height)
        // Elder tuft.
        if stage == .elder {
            f.stamp(["t.t", ".t."], x: m.centre - 1, y: m.top - 1)
        }
        return f
    }

    // MARK: - Faces

    private enum Eyes { case open, closed, wide, droopy, happy }
    private enum Mouth { case smile, flat, frown, open, grin, none }

    private static func face(_ f: inout PixelFrame, stage: LifeStage, eyes: Eyes, mouth: Mouth, cheeks: Bool = false) {
        let m = metrics(for: stage)
        let gap = max(2, m.width / 4)
        let lx = m.centre - gap
        let rx = m.centre + gap - 1
        let ey = m.eyeRow
        switch eyes {
        case .open:
            f.stamp(["e", "e"], x: lx, y: ey)
            f.stamp(["e", "e"], x: rx, y: ey)
        case .closed:
            f.stamp(["oo"], x: lx, y: ey + 1)
            f.stamp(["oo"], x: rx - 1, y: ey + 1)
        case .wide:
            f.stamp(["ee", "ee"], x: lx - 1, y: ey)
            f.stamp(["ee", "ee"], x: rx, y: ey)
        case .droopy:
            f.stamp(["ee"], x: lx, y: ey + 1)
            f.stamp(["ee"], x: rx - 1, y: ey + 1)
        case .happy:
            f.stamp([".e.", "e.e"], x: lx - 1, y: ey)
            f.stamp([".e.", "e.e"], x: rx - 1, y: ey)
        }
        let my = ey + 3
        switch mouth {
        case .smile: f.stamp(["e..e", ".ee."], x: m.centre - 2, y: my)
        case .flat: f.stamp(["eee"], x: m.centre - 1, y: my)
        case .frown: f.stamp([".ee.", "e..e"], x: m.centre - 2, y: my)
        case .open: f.stamp(["ee", "ee"], x: m.centre - 1, y: my)
        case .grin: f.stamp(["eeee", ".rr."], x: m.centre - 2, y: my)
        case .none: break
        }
        if cheeks {
            f.stamp(["r"], x: lx - 2, y: ey + 2)
            f.stamp(["r"], x: rx + 2, y: ey + 2)
        }
    }

    // MARK: - Moods

    private static func moodFrames(_ mood: Mood, stage: LifeStage) -> [PixelFrame] {
        let m = metrics(for: stage)
        switch mood {
        case .asleep:
            var a = body(stage: stage, earsDown: true)
            face(&a, stage: stage, eyes: .closed, mouth: .none)
            var b = a
            a.stamp(["aa", ".a", "aa"], x: m.left + m.width, y: m.top - 4)
            b.stamp(["aaa", "..a", ".a.", "a..", "aaa"], x: m.left + m.width + 1, y: m.top - 7)
            return [a, b]
        case .hungry:
            var a = body(stage: stage)
            face(&a, stage: stage, eyes: .wide, mouth: .open)
            var b = body(stage: stage)
            face(&b, stage: stage, eyes: .wide, mouth: .flat)
            // An empty gumnut cup beside it.
            let cup = ["o...o", "oo.oo", ".ooo."]
            a.stamp(cup, x: 0, y: PixelFrame.size - 4)
            b.stamp(cup, x: 0, y: PixelFrame.size - 4)
            return [a, b.shifted(dx: 0, dy: 0)]
        case .grubby:
            var a = body(stage: stage, earsDown: true)
            face(&a, stage: stage, eyes: .droopy, mouth: .flat)
            var b = a
            a.stamp(["g", ".", "g"], x: m.left + 3, y: m.top + 3)
            a.stamp(["g.g"], x: m.left + m.width - 5, y: m.top + m.height - 3)
            b.stamp(["g", "g"], x: m.left + 4, y: m.top + 4)
            b.stamp(["g..g"], x: m.left + m.width - 6, y: m.top + m.height - 3)
            return [a, b]
        case .sleepy:
            var a = body(stage: stage, earsDown: true)
            face(&a, stage: stage, eyes: .droopy, mouth: .flat)
            var b = body(stage: stage, earsDown: true)
            face(&b, stage: stage, eyes: .closed, mouth: .open)
            return [a, a, b]
        case .glum:
            var a = body(stage: stage, earsDown: true)
            face(&a, stage: stage, eyes: .droopy, mouth: .frown)
            var b = a
            b.stamp(["a", "a"], x: m.centre + m.width / 4 + 1, y: m.eyeRow + 2)
            return [a, b]
        case .content:
            var a = body(stage: stage)
            face(&a, stage: stage, eyes: .open, mouth: .smile)
            var blink = body(stage: stage)
            face(&blink, stage: stage, eyes: .closed, mouth: .smile)
            return [a, a, a.shifted(dx: 0, dy: -1), a, blink]
        case .joyful:
            var a = body(stage: stage)
            face(&a, stage: stage, eyes: .happy, mouth: .grin, cheeks: true)
            var b = a.shifted(dx: 0, dy: -2)
            b.stamp(["a.a", ".a."], x: 1, y: 2)
            b.stamp(["a.a", ".a."], x: PixelFrame.size - 4, y: 3)
            return [a, b]
        }
    }

    // MARK: - Reactions

    private static func reactionFrames(_ reaction: PetReaction, stage: LifeStage) -> [PixelFrame] {
        let m = metrics(for: stage)
        switch reaction {
        case .feed:
            let nut = [".o.", "oso", ".o."]
            var a = body(stage: stage)
            face(&a, stage: stage, eyes: .wide, mouth: .open)
            a.stamp(nut, x: m.centre - 1, y: 0)
            var b = body(stage: stage)
            face(&b, stage: stage, eyes: .happy, mouth: .open)
            b.stamp(nut, x: m.centre - 1, y: m.top - 4)
            var c = body(stage: stage)
            face(&c, stage: stage, eyes: .happy, mouth: .flat, cheeks: true)
            var d = body(stage: stage)
            face(&d, stage: stage, eyes: .happy, mouth: .smile, cheeks: true)
            return [a, b, c, d, c, d]
        case .clean:
            var frames: [PixelFrame] = []
            for i in 0..<4 {
                var f = body(stage: stage)
                face(&f, stage: stage, eyes: i < 2 ? .closed : .happy, mouth: .smile)
                let sparkle = [".a.", "aaa", ".a."]
                f.stamp(sparkle, x: (i % 2 == 0) ? 1 : PixelFrame.size - 4, y: 2 + i * 2)
                f.stamp(["a"], x: (i % 2 == 0) ? PixelFrame.size - 3 : 2, y: 10 - i)
                frames.append(f)
            }
            return frames
        case .play:
            var base = body(stage: stage)
            face(&base, stage: stage, eyes: .happy, mouth: .grin, cheeks: true)
            return [base, base.shifted(dx: 0, dy: -2), base.shifted(dx: 0, dy: -4), base.shifted(dx: 0, dy: -2), base]
        }
    }

    // MARK: - Stage

    private static func stageFrames(stage: LifeStage) -> [PixelFrame] {
        var base = body(stage: stage)
        face(&base, stage: stage, eyes: .happy, mouth: .smile, cheeks: true)
        var noteLeft = base.shifted(dx: -2, dy: 0)
        noteLeft.stamp([".aa", ".a.", "aa."], x: PixelFrame.size - 5, y: 1)
        var noteRight = base.shifted(dx: 2, dy: 0)
        noteRight.stamp(["aa.", ".a.", ".aa"], x: 1, y: 2)
        return [base, noteLeft, base.shifted(dx: 0, dy: -1), noteRight]
    }
}
