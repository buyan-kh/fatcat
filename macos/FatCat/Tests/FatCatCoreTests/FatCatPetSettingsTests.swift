import Foundation
import Testing
@testable import FatCatCore

struct FatCatPetSettingsTests {
    @Test func defaultsAreCalmAndComfortablySized() {
        let settings = FatCatPetSettings()

        #expect(settings.petSize == 220)
        #expect(settings.movementMode == .calm)
        #expect(settings.spokenReplies)
        #expect(settings.previewAnimationKey == nil)
    }

    @Test func movementModesUseTheIntendedIdleIntervals() {
        #expect(FatCatMovementMode.off.idleInterval.isInfinite)
        #expect(FatCatMovementMode.calm.idleInterval == 120)
        #expect(FatCatMovementMode.playful.idleInterval == 60)
    }

    @Test func sizeAndAnimationAreSanitized() {
        #expect(FatCatPetSettings(petSize: 40).petSize == 120)
        #expect(FatCatPetSettings(petSize: 900).petSize == 360)
        #expect(FatCatPetSettings(previewAnimationKey: "thinking").previewAnimationKey == "thinking")
        #expect(FatCatPetSettings(previewAnimationKey: "not-real").previewAnimationKey == nil)
    }

    @Test func settingsRoundTripThroughUserDefaults() {
        let suiteName = "FatCatPetSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = FatCatPetSettingsStore(defaults: defaults)
        let expected = FatCatPetSettings(
            petSize: 310,
            movementMode: .playful,
            spokenReplies: false,
            previewAnimationKey: "celebrate"
        )

        store.save(expected)

        #expect(store.load() == expected)
    }

    @Test func resizingKeepsThePetCenterStill() {
        let origin = FatCatPetSettings.resizedOrigin(
            from: PetPosition(x: 100, y: 200),
            oldSize: 220,
            newSize: 320
        )

        #expect(origin == PetPosition(x: 50, y: 150))
    }

    @Test func voiceStateEmitsOnlyFinalNonemptyTranscripts() {
        var voice = FatCatVoiceState()
        voice.beginListening()
        #expect(voice.isListening)
        #expect(voice.accept(transcript: "still listening", isFinal: false) == nil)
        #expect(voice.accept(transcript: "  ask FatCat  ", isFinal: true) == "ask FatCat")
        #expect(!voice.isListening)
        #expect(voice.accept(transcript: "   ", isFinal: true) == nil)

        voice.beginSpeaking()
        #expect(voice.isSpeaking)
        voice.endSpeaking()
        #expect(!voice.isSpeaking)
    }
}
