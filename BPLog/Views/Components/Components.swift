import SwiftUI

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppColors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

struct CategoryBadge: View {
    let category: BPCategory

    var body: some View {
        Text(category.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(category.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(category.color.opacity(0.14)))
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

/// Full-width 56pt primary action, thumb-reachable at the bottom of the screen.
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
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isEnabled ? AppColors.accent : AppColors.pulse.opacity(0.5))
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
