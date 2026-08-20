import SwiftUI

/// Filter tabs (ADR-005).
///
/// The stock segmented control is the single most recognisable piece of iOS furniture, and it sat
/// at the top of the sheet where the eye lands first — a grey plastic strip on a paper page. These
/// are the same three choices, set as small caps over a plain rule.
///
/// Two louder versions were tried and dropped: a filled chip, which read as a button pretending to
/// be a tab, and a brushed ink stroke, which was the most decorated thing on a page whose job is to
/// list places. The rule under the chosen tab is a border and nothing else — no second impression,
/// no ink. What it has to do is say which of three words is on, and a straight line does that.
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
                        // A border under the word, not a container around it.
                        .overlay(alignment: .bottom) {
                            if isSelected {
                                Rectangle()
                                    .fill(Theme.ink)
                                    .frame(height: 2.5)
                                    .offset(y: 8)
                                    .matchedGeometryEffect(id: "rule", in: chip)
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
