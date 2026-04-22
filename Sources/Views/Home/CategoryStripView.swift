import SwiftUI

// MARK: - CategoryStripView
//
// A vertical strip of category cells on the left side of the dartboard.
// Swipe up/down (or tap) to select a category. The selected cell shows
// the label; others show only the icon at reduced opacity.
// Only categories visible for the current life stage are shown.
// Snap behaviour uses spring animation for a physical feel.

struct CategoryStripView: View {
    @ObservedObject var viewModel: DartboardViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cellHeight: CGFloat = 60
    private let stripWidth: CGFloat = 48

    private var categories: [DartboardCategory] { viewModel.visibleCategories }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(categories, id: \.rawValue) { category in
                categoryCell(category)
            }
        }
        .frame(width: stripWidth)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 4, y: 0)
        .shadow(color: .black.opacity(0.06), radius: 2, x: 2, y: 0)
        .gesture(stripGesture)
    }

    // MARK: - Cell

    private func categoryCell(_ category: DartboardCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            viewModel.categoryStripSnapped(to: category)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: category.sfSymbol)
                    .font(.system(isSelected ? .title3 : .body, design: .default).weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : category.color.opacity(0.8))
                    .accessibilityHidden(true)

                if isSelected {
                    Text(category.label)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        .accessibilityHidden(true)
                }
            }
            .frame(width: stripWidth, height: cellHeight)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? category.color
                          : category.color.opacity(0.18))
            )
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .animation(
            reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7),
            value: viewModel.selectedCategory
        )
        .accessibilityLabel(isSelected ? "\(category.labelString), \(String(localized: "selected"))" : category.labelString)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isSelected ? String(localized: "Currently selected category") : String(format: String(localized: "Switch to %@"), category.labelString))
    }

    // MARK: - Swipe gesture

    private var stripGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let dy = value.translation.height
                let predicted = value.predictedEndTranslation.height
                let effective = abs(predicted) > abs(dy) ? predicted : dy
                let threshold: CGFloat = cellHeight * 0.4
                let cats = categories
                guard let currentIdx = cats.firstIndex(of: viewModel.selectedCategory) else { return }

                if effective < -threshold {
                    // swipe up → previous category
                    let nextIdx = max(0, currentIdx - 1)
                    viewModel.categoryStripSnapped(to: cats[nextIdx])
                } else if effective > threshold {
                    // swipe down → next category
                    let nextIdx = min(cats.count - 1, currentIdx + 1)
                    viewModel.categoryStripSnapped(to: cats[nextIdx])
                }
            }
    }
}

// MARK: - Preview

#Preview {
    let vm = DartboardViewModel(cycleStore: CycleStore())
    return HStack(spacing: 16) {
        CategoryStripView(viewModel: vm)
        Spacer()
    }
    .padding()
    .background(AppTheme.Colors.background)
}
