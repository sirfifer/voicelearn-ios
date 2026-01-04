// UnaMentis - Formula Renderer View
// Native LaTeX rendering using SwiftMath
//
// Part of UI/UX (TDD Section 10)

import SwiftUI

#if canImport(SwiftMath)
import SwiftMath
#endif

// MARK: - Formula Renderer View

/// View that renders LaTeX formulas using SwiftMath library
/// Falls back to styled text representation if SwiftMath is unavailable
public struct FormulaRendererView: View {
    /// The LaTeX formula string to render
    let latex: String

    /// Font size for the formula (in points)
    var fontSize: CGFloat = 18

    /// Text color for the formula
    var textColor: Color = .primary

    /// Background color
    var backgroundColor: Color = .clear

    /// Whether to use display mode (block) or inline mode
    var displayMode: Bool = true

    public init(
        latex: String,
        fontSize: CGFloat = 18,
        textColor: Color = .primary,
        backgroundColor: Color = .clear,
        displayMode: Bool = true
    ) {
        self.latex = latex
        self.fontSize = fontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.displayMode = displayMode
    }

    public var body: some View {
        #if canImport(SwiftMath)
        SwiftMathView(latex: latex, fontSize: fontSize, textColor: textColor)
            .padding(displayMode ? 12 : 4)
            .background(backgroundColor)
        #else
        FallbackFormulaView(
            latex: latex,
            fontSize: fontSize,
            textColor: textColor,
            displayMode: displayMode
        )
        .padding(displayMode ? 12 : 4)
        .background(backgroundColor)
        #endif
    }
}

// MARK: - SwiftMath Wrapper View

#if canImport(SwiftMath)
/// SwiftUI wrapper for SwiftMath's MTMathUILabel
struct SwiftMathView: View {
    let latex: String
    let fontSize: CGFloat
    let textColor: Color

    var body: some View {
        MathViewRepresentable(latex: latex, fontSize: fontSize, textColor: textColor)
    }
}

#if os(iOS)
/// UIViewRepresentable wrapper for MTMathUILabel on iOS
struct MathViewRepresentable: UIViewRepresentable {
    let latex: String
    let fontSize: CGFloat
    let textColor: Color

    func makeUIView(context _: Context) -> MTMathUILabel {
        let mathLabel = MTMathUILabel()
        mathLabel.latex = latex
        mathLabel.fontSize = fontSize
        mathLabel.textColor = UIColor(textColor)
        mathLabel.textAlignment = .center
        mathLabel.labelMode = .display
        return mathLabel
    }

    func updateUIView(_ uiView: MTMathUILabel, context _: Context) {
        uiView.latex = latex
        uiView.fontSize = fontSize
        uiView.textColor = UIColor(textColor)
    }
}
#else
/// NSViewRepresentable wrapper for MTMathUILabel on macOS
struct MathViewRepresentable: NSViewRepresentable {
    let latex: String
    let fontSize: CGFloat
    let textColor: Color

    func makeNSView(context _: Context) -> MTMathUILabel {
        let mathLabel = MTMathUILabel()
        mathLabel.latex = latex
        mathLabel.fontSize = fontSize
        mathLabel.textColor = NSColor(textColor)
        mathLabel.textAlignment = .center
        mathLabel.labelMode = .display
        return mathLabel
    }

    func updateNSView(_ nsView: MTMathUILabel, context _: Context) {
        nsView.latex = latex
        nsView.fontSize = fontSize
        nsView.textColor = NSColor(textColor)
    }
}
#endif
#endif

// MARK: - Fallback Formula View

/// Fallback view when SwiftMath is not available
/// Uses Unicode approximations for common LaTeX symbols
struct FallbackFormulaView: View {
    let latex: String
    let fontSize: CGFloat
    let textColor: Color
    let displayMode: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(formatLatexForDisplay(latex))
                .font(.system(size: fontSize, design: .serif))
                .italic()
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)

            if displayMode {
                Text("(LaTeX rendering)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Convert LaTeX to Unicode approximation for display
    private func formatLatexForDisplay(_ latex: String) -> String {
        var result = latex

        // Greek letters
        let greekLetters: [String: String] = [
            "\\alpha": "\u{03B1}", "\\beta": "\u{03B2}", "\\gamma": "\u{03B3}",
            "\\delta": "\u{03B4}", "\\epsilon": "\u{03B5}", "\\zeta": "\u{03B6}",
            "\\eta": "\u{03B7}", "\\theta": "\u{03B8}", "\\iota": "\u{03B9}",
            "\\kappa": "\u{03BA}", "\\lambda": "\u{03BB}", "\\mu": "\u{03BC}",
            "\\nu": "\u{03BD}", "\\xi": "\u{03BE}", "\\pi": "\u{03C0}",
            "\\rho": "\u{03C1}", "\\sigma": "\u{03C3}", "\\tau": "\u{03C4}",
            "\\upsilon": "\u{03C5}", "\\phi": "\u{03C6}", "\\chi": "\u{03C7}",
            "\\psi": "\u{03C8}", "\\omega": "\u{03C9}",
            "\\Alpha": "\u{0391}", "\\Beta": "\u{0392}", "\\Gamma": "\u{0393}",
            "\\Delta": "\u{0394}", "\\Theta": "\u{0398}", "\\Lambda": "\u{039B}",
            "\\Xi": "\u{039E}", "\\Pi": "\u{03A0}", "\\Sigma": "\u{03A3}",
            "\\Phi": "\u{03A6}", "\\Psi": "\u{03A8}", "\\Omega": "\u{03A9}",
        ]

        // Mathematical operators
        let operators: [String: String] = [
            "\\sum": "\u{2211}", "\\prod": "\u{220F}", "\\int": "\u{222B}",
            "\\partial": "\u{2202}", "\\nabla": "\u{2207}", "\\infty": "\u{221E}",
            "\\pm": "\u{00B1}", "\\mp": "\u{2213}", "\\times": "\u{00D7}",
            "\\div": "\u{00F7}", "\\cdot": "\u{00B7}", "\\sqrt": "\u{221A}",
            "\\approx": "\u{2248}", "\\neq": "\u{2260}", "\\leq": "\u{2264}",
            "\\geq": "\u{2265}", "\\subset": "\u{2282}", "\\supset": "\u{2283}",
            "\\in": "\u{2208}", "\\forall": "\u{2200}", "\\exists": "\u{2203}",
            "\\rightarrow": "\u{2192}", "\\leftarrow": "\u{2190}",
            "\\Rightarrow": "\u{21D2}", "\\Leftarrow": "\u{21D0}",
            "\\leftrightarrow": "\u{2194}", "\\Leftrightarrow": "\u{21D4}",
        ]

        // Apply substitutions
        for (latex_sym, unicode) in greekLetters {
            result = result.replacingOccurrences(of: latex_sym, with: unicode)
        }
        for (latex_sym, unicode) in operators {
            result = result.replacingOccurrences(of: latex_sym, with: unicode)
        }

        // Handle fractions (simplified)
        // \frac{a}{b} -> a/b
        let fracPattern = #"\\frac\{([^}]*)\}\{([^}]*)\}"#
        if let regex = try? NSRegularExpression(pattern: fracPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: "($1)/($2)"
            )
        }

        // Handle superscripts (simplified)
        // ^{n} -> ^n
        result = result.replacingOccurrences(of: "^{", with: "^")
        result = result.replacingOccurrences(of: "_{", with: "_")

        // Remove remaining braces
        result = result.replacingOccurrences(of: "{", with: "")
        result = result.replacingOccurrences(of: "}", with: "")

        // Remove remaining backslashes from unhandled commands
        result = result.replacingOccurrences(of: "\\", with: "")

        return result
    }
}

// MARK: - Enhanced Equation Asset View

/// Enhanced equation view that uses FormulaRendererView for LaTeX rendering
public struct EnhancedEquationAssetView: View {
    let latex: String
    let title: String?
    let semantics: FormulaSemantics?
    @Binding var isFullscreen: Bool

    public init(
        latex: String,
        title: String? = nil,
        semantics: FormulaSemantics? = nil,
        isFullscreen: Binding<Bool>
    ) {
        self.latex = latex
        self.title = title
        self.semantics = semantics
        self._isFullscreen = isFullscreen
    }

    public var body: some View {
        VStack(spacing: 8) {
            Button {
                isFullscreen = true
            } label: {
                VStack(spacing: 8) {
                    FormulaRendererView(
                        latex: latex,
                        fontSize: 20,
                        displayMode: true
                    )
                    .frame(minHeight: 40)

                    if let title = title {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let semantics = semantics, let commonName = semantics.commonName {
                        Text(commonName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(semantics?.commonName ?? title ?? "Mathematical formula")
        .accessibilityHint("Double tap to view fullscreen")
    }
}

// MARK: - Formula Semantics

/// Semantic information about a formula
public struct FormulaSemantics: Codable, Sendable {
    /// Category of the formula (e.g., algebraic, calculus, physics)
    public var category: String?

    /// Common name (e.g., "Quadratic Formula", "Pythagorean Theorem")
    public var commonName: String?

    /// Variable definitions
    public var variables: [VariableDefinition]?

    public struct VariableDefinition: Codable, Sendable {
        public var symbol: String
        public var meaning: String
        public var unit: String?
    }

    public init(
        category: String? = nil,
        commonName: String? = nil,
        variables: [VariableDefinition]? = nil
    ) {
        self.category = category
        self.commonName = commonName
        self.variables = variables
    }
}

// MARK: - Inline Formula View

/// Compact inline formula view for embedding in text
public struct InlineFormulaView: View {
    let latex: String

    public init(latex: String) {
        self.latex = latex
    }

    public var body: some View {
        FormulaRendererView(
            latex: latex,
            fontSize: 14,
            displayMode: false
        )
    }
}

// MARK: - Fullscreen Formula View

/// Fullscreen view for formulas with additional context
public struct FullscreenFormulaView: View {
    let latex: String
    let title: String?
    let semantics: FormulaSemantics?
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Main formula display
                    FormulaRendererView(
                        latex: latex,
                        fontSize: 32,
                        displayMode: true
                    )
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 4)
                    }
                    .padding()

                    // Semantics section
                    if let semantics = semantics {
                        VStack(alignment: .leading, spacing: 16) {
                            if let commonName = semantics.commonName {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Name")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(commonName)
                                        .font(.headline)
                                }
                            }

                            if let category = semantics.category {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Category")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(category.capitalized)
                                        .font(.subheadline)
                                }
                            }

                            if let variables = semantics.variables, !variables.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Variables")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    ForEach(variables, id: \.symbol) { variable in
                                        HStack {
                                            Text(variable.symbol)
                                                .font(.system(.body, design: .serif))
                                                .italic()
                                                .frame(width: 30)

                                            Text("=")
                                                .foregroundStyle(.secondary)

                                            Text(variable.meaning)
                                                .font(.subheadline)

                                            if let unit = variable.unit {
                                                Text("(\(unit))")
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        }
                        .padding(.horizontal)
                    }

                    // Raw LaTeX (for reference)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LaTeX Source")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(latex)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }
            }
            .navigationTitle(title ?? "Formula")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Formula Renderer") {
    VStack(spacing: 20) {
        FormulaRendererView(
            latex: "E = mc^2",
            fontSize: 24
        )

        FormulaRendererView(
            latex: "x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}",
            fontSize: 20
        )

        FormulaRendererView(
            latex: "\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}",
            fontSize: 20
        )

        InlineFormulaView(latex: "a^2 + b^2 = c^2")
    }
    .padding()
}
