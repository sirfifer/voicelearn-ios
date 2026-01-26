//
//  KBDomainMixView.swift
//  UnaMentis
//
//  Domain mix configuration view with linked sliders.
//  All sliders are linked to maintain a sum of 100%.
//

import SwiftUI

/// View for configuring domain weights with linked sliders.
struct KBDomainMixView: View {
    @Binding var domainMix: KBDomainMix
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 4) {
                    // Header explanation
                    headerSection

                    // Domain sliders
                    ForEach(KBDomain.allCases) { domain in
                        domainSliderRow(for: domain)
                    }

                    // Reset button
                    resetButton
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color.kbBgPrimary)
            .navigationTitle("Domain Mix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Adjust Question Mix")
                .font(.headline)
                .foregroundColor(.kbTextPrimary)

            Text("Sliders are linked to always total 100%. Moving one slider adjusts the others proportionally.")
                .font(.caption)
                .foregroundColor(.kbTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.kbBgSecondary)
        .cornerRadius(10)
    }

    // MARK: - Domain Slider Row

    private func domainSliderRow(for domain: KBDomain) -> some View {
        HStack(spacing: 8) {
            // Domain icon and name (fixed width for alignment)
            HStack(spacing: 6) {
                Image(systemName: domain.icon)
                    .font(.system(size: 14))
                    .foregroundColor(domain.color)
                    .frame(width: 18)

                Text(domain.displayName)
                    .font(.subheadline)
                    .foregroundColor(.kbTextPrimary)
                    .lineLimit(1)
            }
            .frame(width: 165, alignment: .leading)

            // Slider (takes remaining space)
            DomainSlider(
                value: Binding(
                    get: { domainMix.weight(for: domain) },
                    set: { domainMix.setWeight(for: domain, to: $0) }
                ),
                color: domain.color
            )

            // Percentage display
            Text("\(Int(domainMix.percentage(for: domain)))%")
                .font(.subheadline.monospacedDigit())
                .fontWeight(.medium)
                .foregroundColor(domain.color)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                domainMix.resetToDefault()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset to Default")
            }
            .font(.subheadline)
            .foregroundColor(.kbMastered)
        }
        .padding(.top, 4)
    }
}

// MARK: - Domain Slider

/// Custom slider styled for domain mix
private struct DomainSlider: View {
    @Binding var value: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.kbBorder)
                    .frame(height: 6)

                // Filled portion
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.7))
                    .frame(width: max(0, geometry.size.width * value), height: 6)

                // Thumb
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: max(0, min(geometry.size.width - 16, geometry.size.width * value - 8)))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let newValue = gesture.location.x / geometry.size.width
                                value = max(0, min(1, newValue))
                            }
                    )
            }
        }
        .frame(height: 16)
        .accessibilityElement()
        .accessibilityLabel("Domain weight slider")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(1, value + 0.05)
            case .decrement:
                value = max(0, value - 0.05)
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var mix = KBDomainMix.default

        var body: some View {
            KBDomainMixView(domainMix: $mix)
        }
    }

    return PreviewWrapper()
}
