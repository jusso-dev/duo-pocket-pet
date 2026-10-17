import Testing
@testable import PocketPetCore

@Suite("Glance content")
struct GlanceContentTests {
    @Test func asleepPetReadsAsOneSentence() {
        let content = GlanceContent(state: .sample(mood: .asleep, stage: .young, name: "Bip"))
        #expect(content.accessibilityLabel == "Bip is asleep")
        #expect(content.accessibilityValue == "Young")
        #expect(content.moodLine == "Asleep")
        #expect(content.stageLabel == "Young")
    }

    @Test func needyMoodsSayTheyNeedYou() {
        let content = GlanceContent(state: .sample(mood: .grubby, stage: .elder, name: "Moss"))
        #expect(content.accessibilityLabel == "Moss is in need of a clean")
        #expect(content.moodLine == "In need of a clean")
        #expect(content.accessibilityValue == "Elder. Needs you")
        #expect(content.needsAttention)
    }

    @Test func everyMoodHasALabelNamingThePet() {
        for mood in Mood.allCases {
            let content = GlanceContent(state: .sample(mood: mood, stage: .grown, name: "Bip"))
            #expect(content.accessibilityLabel.hasPrefix("Bip is "))
            #expect(!content.moodLine.isEmpty)
            #expect(content.moodLine.first?.isUppercase == true)
        }
    }
}
