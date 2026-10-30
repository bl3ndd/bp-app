import SwiftUI

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    /// White card on the paper background: hairline border, no shadow.
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous).fill(AppColors.bgCard))
            .overlay(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous)
                .strokeBorder(AppColors.separator, lineWidth: 1))
    }
}

struct CategoryBadge: View {
    let category: BPCategory

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(category.color).frame(width: 8, height: 8)
            Text(category.title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(category.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(category.color.opacity(0.13)))
    }
}

/// Where a reading sits on the six categories, Low to Crisis: the current one in
/// full color with a marker, the rest faded. Backs the badge's color and name
/// with a position, which also works for color-blind users.
struct CategoryScale: View {
    let category: BPCategory
    var showsLabels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 5) {
                ForEach(BPCategory.allCases, id: \.self) { c in
                    VStack(spacing: 3) {
                        Capsule()
                            .fill(c.color.opacity(c == category ? 1 : 0.3))
                            .frame(height: c == category ? 10 : 8)
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(c == category ? AppColors.textPrimary : .clear)
                        if showsLabels {
                            Text(c.shortTitle)
                                .font(.caption2.weight(c == category ? .bold : .regular))
                                .foregroundStyle(c == category ? AppColors.textPrimary : AppColors.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(category.title), \(BPCategory.allCases.firstIndex(of: category)! + 1) of \(BPCategory.allCases.count) on the blood pressure scale")
    }
}

/// Segmented choice on a warm fill track, with 44pt segments. Selected segments
/// carry the accessibility "selected" trait, like the system control.
struct SegmentedChips<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.body.weight(on ? .semibold : .regular))
                        .foregroundStyle(on ? AppColors.textPrimary : AppColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(on ? AppColors.bgCard : .clear)
                            .shadow(color: .black.opacity(on ? 0.08 : 0), radius: 2, y: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(AppColors.bgInput))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// The category's plain-language line as a tinted callout with an icon, so it
/// gets noticed rather than skimmed past. Shown where a single reading is shown.
struct CategoryNote: View {
    let category: BPCategory

    var body: some View {
        if let note = category.note {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(category.color)
                    .accessibilityHidden(true)
                Text(note)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(category.color.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(category.color.opacity(0.4), lineWidth: 1))
        }
    }
}

/// "128/82 mmHg" with an optional pulse line, sized for reading at arm's length.
struct ReadingNumbers: View {
    let systolic: Int
    let diastolic: Int
    var pulse: Int?
    var size: CGFloat = 52
    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(systolic)/\(diastolic)")
                    .font(AppFont.number(size * scale))
                    .foregroundStyle(AppColors.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("mmHg")
                    .font(.headline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            if let pulse {
                Label("\(pulse) bpm", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Full-width 58pt capsule primary action, thumb-reachable at the bottom of the screen.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }

    private struct PrimaryButtonBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    Capsule()
                        .fill(isEnabled ? AppColors.accentFill : AppColors.pulse.opacity(0.5))
                        .opacity(configuration.isPressed ? 0.8 : 1)
                )
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
