import SwiftUI

/// Filter tabs, printed (ADR-005).
///
/// The stock segmented control is the single most recognisable piece of iOS furniture, and it sat
/// at the top of the sheet where the eye lands first — a grey plastic strip on a paper page. These
/// are the same three choices, set as small caps with a stroke drawn under the chosen one — the
/// mark a reader makes in a book. A filled chip was tried first and read as a button pretending to
/// be a tab: too big, too loud, and the only solid shape on a page made of type and paper.
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

    @Namespace private var chip

    var body: some View {
        HStack(spacing: Theme.Space.regular) {
            ForEach(tabs) { tab in
                let isSelected = tab.value == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                        selection = tab.value
                    }
                } label: {
                    Text(tab.title)
                        .font(Theme.smallCaps(.caption))
                        .tracking(0.9)
                        .foregroundStyle(isSelected ? Theme.ink : Theme.inkSecondary.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        // The mark is an annotation on the word — a stroke someone drew under it —
                        // not a container the word sits inside.
                        .overlay(alignment: .bottom) {
                            if isSelected {
                                BrushRule()
                                    .fill(Theme.pandan)
                                    .misregistered(BrushRule(), ink: Theme.indigo, opacity: 0.45)
                                    .frame(height: 4)
                                    .offset(y: 8)
                                    .matchedGeometryEffect(id: "stroke", in: chip)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        // Choosing a filter is a small physical act; the tick confirms it landed.
        .sensoryFeedback(.selection, trigger: selection)
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
