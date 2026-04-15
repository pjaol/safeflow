import SwiftUI

// MARK: - PulseView
//
// The daily check-in surface. Three inputs, same screen, no modals:
//
//  Left strip   — tap or swipe up/down to select a category
//  Dartboard    — tap segments to toggle symptoms/mood; long-press centre for notes
//  Flow slider  — horizontal step slider below the board (always visible)
//
// HomeView embeds this as: PulseView(cycleStore: cycleStore)

struct PulseView: View {
    @ObservedObject var cycleStore: CycleStore
    @StateObject private var viewModel: DartboardViewModel

    init(cycleStore: CycleStore) {
        self.cycleStore = cycleStore
        _viewModel = StateObject(wrappedValue: DartboardViewModel(cycleStore: cycleStore))
    }

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.hasLoggedToday {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.accentBlue.opacity(0.7))
                        .accessibilityHidden(true)
                    Text("Logged today")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Logged today")
            }

            ZStack(alignment: .leading) {
                // Board gets the full width — no space stolen by the strip
                DartboardView(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 56)
                    .accessibilityLabel("Symptoms and mood — tap a segment to log it, long press centre to add a note")

                // Strip floats over the left edge of the board
                CategoryStripView(viewModel: viewModel)
                    .frame(width: 48)
                    .accessibilityLabel("Symptom categories")
            }
            .frame(maxWidth: .infinity)

            FlowStepSlider(viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.top, 4)
        }
        .padding(.horizontal, 4)
        .padding(.horizontal, -12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily log")
        .onAppear { viewModel.loadFromStore() }
        .onReceive(cycleStore.objectWillChange) { _ in
            DispatchQueue.main.async { viewModel.loadFromStore() }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        PulseView(cycleStore: CycleStore())
            .frame(height: 300)
        Spacer()
    }
    .padding()
    .background(AppTheme.Colors.background)
}
