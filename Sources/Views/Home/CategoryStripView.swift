import SwiftUI

// MARK: - CategoryStripView
//
// A vertical strip of 4 category cells on the left side of the dartboard.
// Swipe up/down (or tap) to select a category. The selected cell shows
// the label; others show only the icon at reduced opacity.
// Snap behaviour uses spring animation for a physical feel.

struct CategoryStripView: View {
    @ObservedObject var viewModel: DartboardViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cellHeight: CGFloat = 60
    private let stripWidth: CGFloat = 48

    var body: some View {
        VStack(spacing: 0) {
            ForEach(DartboardCategory.allCases, id: \.rawValue) { category in
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
                    .font(.system(size: isSelected ? 20 : 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : category.color.opacity(0.8))

                if isSelected {
                    Text(category.label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
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
        .accessibilityLabel(category.label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Swipe gesture

    private var stripGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let dy = value.translation.height
                let predicted = value.predictedEndTranslation.height
                // Use predicted translation for flick detection
                let effective = abs(predicted) > abs(dy) ? predicted : dy
                let threshold: CGFloat = cellHeight * 0.4
                let current = viewModel.selectedCategory.rawValue
                let count   = DartboardCategory.allCases.count

                if effective < -threshold {
                    // swipe up → previous category
                    let next = max(0, current - 1)
                    if let cat = DartboardCategory(rawValue: next) {
                        viewModel.categoryStripSnapped(to: cat)
                    }
                } else if effective > threshold {
                    // swipe down → next category
                    let next = min(count - 1, current + 1)
                    if let cat = DartboardCategory(rawValue: next) {
                        viewModel.categoryStripSnapped(to: cat)
                    }
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
