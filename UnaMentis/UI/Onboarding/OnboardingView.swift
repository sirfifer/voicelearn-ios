// UnaMentis - Onboarding View
// First-time user welcome and setup guide
//
// Part of UI/UX Help System

import SwiftUI

/// First-time user onboarding experience
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            customImage: "Logo",
            iconColor: .blue,
            title: "Welcome to UnaMentis",
            subtitle: "Learn Through Voice",
            description: "Have natural voice conversations with an AI learning assistant. Ask questions, explore topics, and learn at your own pace.",
            tips: [
                "Speak naturally, just like talking to a teacher",
                "Ask follow-up questions anytime",
                "Interrupt the AI by speaking"
            ]
        ),
        OnboardingPage(
            icon: "book.circle.fill",
            iconColor: .orange,
            title: "Structured Learning",
            subtitle: "Curriculum-Based Lessons",
            description: "Follow structured curricula with topics organized for progressive learning. Track your mastery and progress.",
            tips: [
                "Browse available curricula in the Curriculum tab",
                "Each topic has audio narration and visuals",
                "Your progress is saved automatically"
            ]
        ),
        OnboardingPage(
            icon: "iphone.circle.fill",
            iconColor: .green,
            title: "Works Offline",
            subtitle: "On-Device AI",
            description: "Use on-device AI for free, private sessions that work without internet. Or connect to cloud services for more power.",
            tips: [
                "On-device speech recognition is free",
                "Self-host AI on your Mac for unlimited use",
                "Cloud services offer the best quality"
            ]
        ),
        OnboardingPage(
            icon: "hand.raised.circle.fill",
            iconColor: .purple,
            title: "Hands-Free Learning",
            subtitle: "Use Siri to Start",
            description: "Start learning sessions with your voice using Siri. Perfect for walking, driving, or exercising.",
            tips: [
                "Say \"Hey Siri, talk to UnaMentis\"",
                "Or \"Hey Siri, start a lesson\"",
                "Use headphones for best results"
            ]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header with logo and skip button
            HStack {
                BrandLogo(size: .large)
                    .padding(.leading)
                Spacer()
                Button("Skip") {
                    completeOnboarding()
                }
                .foregroundStyle(.secondary)
                .padding()
            }

            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Navigation buttons
            HStack(spacing: 20) {
                if currentPage > 0 {
                    Button {
                        withAnimation {
                            currentPage -= 1
                        }
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel("Previous page")
                }

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    HStack {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        if currentPage < pages.count - 1 {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .accessibilityLabel(currentPage < pages.count - 1 ? "Next page" : "Complete onboarding and get started")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Onboarding Page Data

struct OnboardingPage {
    let icon: String?
    let customImage: String?
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
    let tips: [String]

    init(icon: String, iconColor: Color, title: String, subtitle: String, description: String, tips: [String]) {
        self.icon = icon
        self.customImage = nil
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.tips = tips
    }

    init(customImage: String, iconColor: Color, title: String, subtitle: String, description: String, tips: [String]) {
        self.icon = nil
        self.customImage = customImage
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.tips = tips
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon or custom image
            if let customImage = page.customImage {
                Image(customImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .accessibilityHidden(true)
            } else if let icon = page.icon {
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundStyle(page.iconColor)
                    .accessibilityHidden(true)
            }

            // Title and subtitle
            VStack(spacing: 8) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.title3)
                    .foregroundStyle(page.iconColor)
            }

            // Description
            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Tips
            VStack(alignment: .leading, spacing: 12) {
                ForEach(page.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(tip)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.title). \(page.subtitle). \(page.description)")
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}

#Preview("Page 2") {
    OnboardingPageView(page: OnboardingPage(
        icon: "book.circle.fill",
        iconColor: .orange,
        title: "Structured Learning",
        subtitle: "Curriculum-Based Lessons",
        description: "Follow structured curricula with topics organized for progressive learning.",
        tips: ["Browse curricula", "Track mastery", "Auto-save progress"]
    ))
}
