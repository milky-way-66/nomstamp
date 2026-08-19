import SwiftUI

/// Filter tabs, printed (ADR-005).
///
/// The stock segmented control is the single most recognisable piece of iOS furniture, and it sat
/// at the top of the sheet where the eye lands first — a grey plastic strip on a paper page. These
/// are the same three choices: small-caps labels with a brushed rule under the chosen one.
///
/// Behaviour is deliberately identical to a picker's: one choice at a time, each tab a button that
/// reports itself selected to assistive technology (TC-N-15), full touch target, labels translated
/// by the string catalogue.
struct InkTabs<Value: Hashable>: View {
    struct Tab: Identifiable {
        let value: Value
        let title: LocalizedStringKey

        var id: Value { value }
    }

    let tabs: [Tab]
    @Binding var selection: Value

    @Namespace private var underline

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.22)) { selection = tab.value }
                } label: {
                    Text(tab.title)
                        .font(Theme.smallCaps(.subheadline))
                        .foregroundStyle(tab.value == selection ? Theme.ink : Theme.inkSecondary)
                        // The rule is an overlay on the word, not on the column, so it is as wide
                        // as what it underlines — a stroke under a label, not a tab indicator.
                        .overlay(alignment: .bottom) {
                            if tab.value == selection {
                                BrushRule()
                                    .fill(Theme.lacquer)
                                    .frame(height: 5)
                                    .offset(y: 9)
                                    // One rule that moves between tabs, rather than three that
                                    // appear and vanish: the ink stays the same ink.
                                    .matchedGeometryEffect(id: "rule", in: underline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab.value == selection ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

/// A rule with a loaded middle and dry ends — a brush, not a border.
struct BrushRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.06
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: rect.midY - rect.height * 0.1),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
