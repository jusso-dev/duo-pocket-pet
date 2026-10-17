import PocketPetCore
import SwiftUI

/// The pet's home: a status strip, the pet on its LCD, its needs as segmented
/// meters, and keycap buttons for Feed, Clean, Play and (without a hinge) Bedtime.
///
/// At accessibility text sizes the screen scrolls and the buttons stack, so
/// nothing truncates or clips off a compact screen.
struct HomeView: View {
    let model: AppModel
    var showsBedtime = false
    @State private var reaction: PetReactionCue?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var scheme

    private var palette: RetroPalette { .current(scheme) }

    var body: some View {
        // On the inner display the pet sits on one side of the fold and the
        // controls on the other, so no button lands on the crease. Without a
        // fold (outer screen, standard iPhone, older iOS) it is one column.
        FoldAwareSplit(includeInactive: true) { _ in
            scrollingIfLarge {
                VStack(spacing: 16) {
                    StatusStrip(state: model.state)
                    petPane(spriteHeight: nil)
                }
                .padding()
            }
        } second: { _ in
            scrollingIfLarge { controlsPane.padding() }
        } fallback: {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    content(spriteHeight: 160)
                }
            } else {
                // Scrolls only when it has to, such as a small phone in landscape.
                ViewThatFits(in: .vertical) {
                    content(spriteHeight: nil)
                    ScrollView {
                        content(spriteHeight: 120)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func scrollingIfLarge<Pane: View>(@ViewBuilder _ pane: () -> Pane) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView { pane() }
        } else {
            pane()
        }
    }

    private func content(spriteHeight: CGFloat?) -> some View {
        VStack(spacing: 16) {
            StatusStrip(state: model.state)
            petPane(spriteHeight: spriteHeight)
            controlsPane
        }
        .padding()
    }

    private func petPane(spriteHeight: CGFloat?) -> some View {
        let state = model.state
        return VStack(spacing: 10) {
            PetSpriteView(state: state, reaction: reaction, halo: scheme == .dark ? palette.inkSoft.color.opacity(0.55) : nil)
                .frame(maxWidth: .infinity, maxHeight: spriteHeight ?? .infinity)
                .frame(height: spriteHeight)
                .overlay(alignment: .topTrailing) {
                    if state.mood.needsAttention {
                        AttentionBlink(colour: palette.alert.color)
                    }
                }

            PixelText(
                text: "\(state.name) is \(state.mood.accessibilityDescription)",
                size: 2,
                colour: palette.ink.color,
                alignment: .centre
            )
        }
        .lcdPanel()
    }

    private var controlsPane: some View {
        VStack(spacing: 16) {
            NeedsPanel(state: model.state)

            if let refusal = model.lastRefusal {
                Text(refusal.message(petName: model.state.name))
                    .font(.callout.monospaced())
                    .foregroundStyle(palette.backdropInk.color)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            ActionRow(buttons: buttons, dynamicTypeSize: dynamicTypeSize)

            if model.remindersOffered {
                Toggle(
                    "Good morning note while \(model.state.name) sleeps",
                    isOn: Binding(get: { model.morningNoteEnabled }, set: { model.setMorningNote($0) })
                )
                .font(.footnote.monospaced())
                .foregroundStyle(palette.backdropInk.color)
                .tint(palette.bezelHighlight.color)
                .accessibilityHint("Sends one note at 8 am while your pet is asleep")
            }
        }
    }

    private var buttons: [ActionRow.Item] {
        var items: [ActionRow.Item] = [
            .init(title: "Feed", icon: .bowl, hint: "Lowers hunger") { perform(.feed, reaction: .feed) },
            .init(title: "Clean", icon: .bubbles, hint: "Restores cleanliness") { perform(.clean, reaction: .clean) },
            .init(title: "Play", icon: .ball, hint: "Raises happiness, uses energy") { perform(.play, reaction: .play) },
        ]
        if showsBedtime {
            if model.state.isAsleep {
                items.append(.init(title: "Wake", icon: .sun, hint: "Wakes your pet") { perform(.wake, reaction: nil) })
            } else {
                items.append(.init(title: "Bedtime", icon: .moon, hint: "Puts your pet to sleep") { perform(.sleep, reaction: nil) })
            }
        }
        return items
    }

    private func perform(_ action: PetAction, reaction kind: PetReaction?) {
        let result = model.perform(action)
        if result == .applied, let kind {
            reaction = PetReactionCue(reaction: kind, startedAt: .now)
        }
        // VoiceOver users hear the outcome, applied or refused.
        AccessibilityNotification.Announcement(result.announcement(for: action, petName: model.state.name)).post()
    }
}

/// The line above the pet: name, life stage, day count and a mood icon, like
/// the status row on an old handheld. One VoiceOver element.
struct StatusStrip: View {
    let state: PetState
    @Environment(\.colorScheme) private var scheme

    private var content: GlanceContent { GlanceContent(state: state) }
    private var day: Int { Int(state.ageSeconds / 86_400) + 1 }

    private var moodIcon: PixelIcon {
        if state.isAsleep { return .moon }
        return content.needsAttention ? .attention : .leaf
    }

    var body: some View {
        let ink = RetroPalette.current(scheme).backdropInk.color
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                PixelText(text: content.name, size: 3, colour: ink).fixedSize()
                PixelText(text: "\(content.stageLabel)  Day \(day)", size: 2, colour: ink).fixedSize()
                Spacer(minLength: 8)
                PixelIconView(icon: moodIcon, scale: 3, colour: ink)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    PixelText(text: content.name, size: 3, colour: ink)
                    Spacer(minLength: 8)
                    PixelIconView(icon: moodIcon, scale: 3, colour: ink)
                }
                PixelText(text: "\(content.stageLabel)  Day \(day)", size: 2, colour: ink)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
        .accessibilityValue("\(content.accessibilityValue). Day \(day)")
        .accessibilityIdentifier("glanceHeader")
    }
}

/// A blinking "needs you" bubble beside the pet. Holds still with Reduce Motion on.
struct AttentionBlink: View {
    let colour: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.6)) { timeline in
            let on = reduceMotion || Int(timeline.date.timeIntervalSinceReferenceDate / 0.6) % 2 == 0
            PixelIconView(icon: .attention, scale: 3, colour: colour)
                .opacity(on ? 1 : 0.15)
        }
        .accessibilityHidden(true)
    }
}

/// Feed, Clean, Play and, without a hinge, Bedtime or Wake, as keycaps.
///
/// Two to a row when they fit, otherwise stacked. At accessibility sizes they
/// always stack, because two big captions can't share a compact screen's width.
struct ActionRow: View {
    struct Item: Identifiable {
        let title: String
        let icon: PixelIcon
        let hint: String
        let action: () -> Void
        var id: String { title }
    }

    let buttons: [Item]
    let dynamicTypeSize: DynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            column
        } else {
            ViewThatFits(in: .horizontal) {
                grid
                column
            }
        }
    }

    private var pairs: [[Item]] {
        stride(from: 0, to: buttons.count, by: 2).map { Array(buttons[$0..<min($0 + 2, buttons.count)]) }
    }

    private var grid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 8) {
            ForEach(pairs, id: \.first?.id) { pair in
                GridRow {
                    ForEach(pair) { ActionButton(item: $0) }
                    if pair.count == 1 { Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                }
            }
        }
    }

    private var column: some View {
        VStack(spacing: 8) { ForEach(buttons) { ActionButton(item: $0) } }
    }
}

struct NeedsPanel: View {
    let state: PetState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = RetroPalette.current(scheme)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Label above bar, so long labels don't squeeze the bars off screen.
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            label(row, ink: p.ink.color)
                            SegmentMeter(value: row.value, lit: p.ink.color, unlit: p.lcdGhost.color)
                        }
                        .needAccessibility(label: row.label, value: row.value)
                    }
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    ForEach(rows) { row in
                        GridRow {
                            label(row, ink: p.ink.color)
                            SegmentMeter(value: row.value, lit: p.ink.color, unlit: p.lcdGhost.color)
                                .frame(minWidth: 96)
                        }
                        .needAccessibility(label: row.label, value: row.value)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lcdPanel()
    }

    private func label(_ row: Row, ink: Color) -> some View {
        HStack(spacing: 6) {
            PixelIconView(icon: row.icon, scale: 2, colour: ink)
            PixelText(text: row.short, size: 2, colour: ink).fixedSize()
        }
    }

    private struct Row: Identifiable {
        let label: String
        let short: String
        let icon: PixelIcon
        let value: Double
        var id: String { label }
    }

    private var rows: [Row] {
        [
            Row(label: "Fullness", short: "Full", icon: .bowl, value: 1 - state.hunger),
            Row(label: "Happiness", short: "Happy", icon: .smile, value: state.happiness),
            Row(label: "Energy", short: "Energy", icon: .bolt, value: state.energy),
            Row(label: "Cleanliness", short: "Clean", icon: .bubbles, value: state.hygiene),
        ]
    }
}

private extension View {
    func needAccessibility(label: String, value: Double) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
}

private struct ActionButton: View {
    let item: ActionRow.Item

    var body: some View {
        Button(action: item.action) {
            KeycapLabel(title: item.title, icon: item.icon)
        }
        .buttonStyle(KeycapButtonStyle())
        .accessibilityLabel(item.title)
        .accessibilityHint(item.hint)
    }
}

#Preview("Home, daylight") {
    HomeView(model: AppModel(store: InMemoryPetStore(.sample(mood: .hungry, stage: .young)), fold: StaticFoldStateService(.open)))
        .background(RetroBackdrop())
}

#Preview("Home, backlight") {
    HomeView(model: AppModel(store: InMemoryPetStore(.sample(mood: .content, stage: .grown)), fold: StaticFoldStateService(.unavailable)), showsBedtime: true)
        .background(RetroBackdrop())
        .preferredColorScheme(.dark)
}

#Preview("Home, largest text") {
    HomeView(model: AppModel(store: InMemoryPetStore(.sample(mood: .grubby, stage: .elder)), fold: StaticFoldStateService(.unavailable)), showsBedtime: true)
        .background(RetroBackdrop())
        .environment(\.dynamicTypeSize, .accessibility5)
}
