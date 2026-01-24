// UnaMentis - Help View
// In-app help following iOS best practices
//
// Provides user guidance for voice commands and app features

import SwiftUI

/// Main help view with organized sections for app features
public struct HelpView: View {
    public init() {}

    public var body: some View {
        List {
            // Voice Commands Section - Primary feature
            Section {
                NavigationLink {
                    VoiceCommandsHelpView()
                } label: {
                    HelpRow(
                        icon: "waveform.circle.fill",
                        iconColor: .blue,
                        title: "Siri Voice Commands",
                        subtitle: "Control UnaMentis hands-free"
                    )
                }
            } header: {
                Text("Getting Started")
            } footer: {
                Text("Use Siri to start conversations and lessons without touching your phone.")
            }

            // Learning Section
            Section("Learning") {
                NavigationLink {
                    FreeformChatHelpView()
                } label: {
                    HelpRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        iconColor: .green,
                        title: "Voice Conversations",
                        subtitle: "Spontaneous learning sessions"
                    )
                }

                NavigationLink {
                    CurriculumHelpView()
                } label: {
                    HelpRow(
                        icon: "book.fill",
                        iconColor: .orange,
                        title: "Curriculum Lessons",
                        subtitle: "Structured topic-based learning"
                    )
                }
            }

            // Knowledge Bowl Section
            Section("Knowledge Bowl") {
                NavigationLink {
                    KBHelpSheet()
                } label: {
                    HelpRow(
                        icon: "trophy.fill",
                        iconColor: .yellow,
                        title: "Knowledge Bowl Training",
                        subtitle: "Competition prep and strategy"
                    )
                }
            }

            // Tips Section
            Section("Tips") {
                NavigationLink {
                    HandsFreeHelpView()
                } label: {
                    HelpRow(
                        icon: "hand.raised.slash.fill",
                        iconColor: .purple,
                        title: "Hands-Free Learning",
                        subtitle: "Learn while walking or exercising"
                    )
                }
            }
        }
        .navigationTitle("Help")
    }
}

// MARK: - Voice Commands Help

struct VoiceCommandsHelpView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("UnaMentis responds to Siri voice commands, letting you start learning sessions without touching your phone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Start a Conversation") {
                VoiceCommandRow(command: "Hey Siri, talk to UnaMentis")
                VoiceCommandRow(command: "Hey Siri, chat with UnaMentis")
                VoiceCommandRow(command: "Hey Siri, start a conversation with UnaMentis")

                Text("Opens the app and immediately starts a voice session. Perfect for spontaneous questions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            Section("Start a Lesson") {
                VoiceCommandRow(command: "Hey Siri, start a lesson in UnaMentis")
                VoiceCommandRow(command: "Hey Siri, teach me about Physics in UnaMentis")
                VoiceCommandRow(command: "Hey Siri, study Quantum Mechanics with UnaMentis")

                Text("Starts a structured lesson from your curriculum library.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            Section("Resume & Progress") {
                VoiceCommandRow(command: "Hey Siri, resume learning in UnaMentis")
                VoiceCommandRow(command: "Hey Siri, continue my lesson in UnaMentis")
                VoiceCommandRow(command: "Hey Siri, show my progress in UnaMentis")

                Text("Pick up where you left off or check your learning statistics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("First Time Setup", systemImage: "info.circle")
                        .font(.subheadline.weight(.medium))

                    Text("After installing UnaMentis, open it once so Siri can recognize the voice commands. You may need to wait a few minutes for Siri to learn the new shortcuts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Voice Commands")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Freeform Chat Help

struct FreeformChatHelpView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Voice conversations let you explore any topic spontaneously. Just start talking and the AI will respond.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("How It Works") {
                HelpStepRow(number: 1, text: "Say \"Hey Siri, talk to UnaMentis\" or tap the microphone button")
                HelpStepRow(number: 2, text: "Wait for the session to start (you'll see the waveform indicator)")
                HelpStepRow(number: 3, text: "Ask any question or request to learn about a topic")
                HelpStepRow(number: 4, text: "The AI responds with voice, and you can continue the conversation naturally")
            }

            Section("Tips") {
                Label("Speak clearly and at a normal pace", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green, .primary)
                Label("You can interrupt the AI by speaking", systemImage: "hand.raised.fill")
                    .foregroundStyle(.orange, .primary)
                Label("Sessions work offline with on-device AI", systemImage: "wifi.slash")
                    .foregroundStyle(.blue, .primary)
            }
        }
        .navigationTitle("Voice Conversations")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Curriculum Help

struct CurriculumHelpView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Curriculum lessons provide structured learning with topics organized into courses. Each lesson covers specific concepts with visual aids.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Starting a Lesson") {
                HelpStepRow(number: 1, text: "Go to the Curriculum tab")
                HelpStepRow(number: 2, text: "Browse or search for a topic")
                HelpStepRow(number: 3, text: "Tap a topic to start the lesson")
                HelpStepRow(number: 4, text: "Or say \"Hey Siri, teach me about [topic] in UnaMentis\"")
            }

            Section("During a Lesson") {
                Label("Progress bar shows your position in the lesson", systemImage: "chart.bar.fill")
                Label("Visual aids appear when relevant", systemImage: "photo.fill")
                Label("Pause/resume controls at the bottom", systemImage: "playpause.fill")
                Label("Ask questions anytime by speaking", systemImage: "bubble.left.fill")
            }

            Section("Tracking Progress") {
                Text("Your mastery level is tracked for each topic. Complete lessons to improve your mastery percentage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Curriculum Lessons")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Hands-Free Help

struct HandsFreeHelpView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("UnaMentis is designed for hands-free learning. Start a session with Siri and continue without ever touching your phone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Perfect For") {
                HandsFreeUseCase(icon: "figure.walk", title: "Walking", description: "Learn during your daily walk or commute")
                HandsFreeUseCase(icon: "car.fill", title: "Driving", description: "Safe, voice-only interaction while driving")
                HandsFreeUseCase(icon: "dumbbell.fill", title: "Exercise", description: "Keep your mind active during workouts")
                HandsFreeUseCase(icon: "house.fill", title: "Housework", description: "Learn while doing chores")
            }

            Section("Best Practices") {
                Label("Use AirPods or headphones for best audio", systemImage: "airpodspro")
                Label("Position phone within speaking distance", systemImage: "iphone.gen3.radiowaves.left.and.right")
                Label("Reduce background noise when possible", systemImage: "speaker.wave.2.fill")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Quick Start", systemImage: "bolt.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.yellow)

                    Text("Just say \"Hey Siri, talk to UnaMentis\" and start asking questions. No setup required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Hands-Free Learning")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Helper Views

struct HelpRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

struct VoiceCommandRow: View {
    let command: String

    var body: some View {
        HStack {
            Image(systemName: "mic.fill")
                .foregroundStyle(.blue)
                .font(.caption)

            Text(command)
                .font(.subheadline.monospaced())
        }
        .padding(.vertical, 2)
        .accessibilityLabel("Voice command: \(command)")
    }
}

struct HelpStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.blue))

            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(text)")
    }
}

struct HandsFreeUseCase: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HelpView()
    }
}

#Preview("Voice Commands") {
    NavigationStack {
        VoiceCommandsHelpView()
    }
}
