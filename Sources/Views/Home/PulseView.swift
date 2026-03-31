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
            ZStack(alignment: .leading) {
                // Board gets the full width — no space stolen by the strip
                DartboardView(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 56)

                // Strip floats over the left edge of the board
                CategoryStripView(viewModel: viewModel)
                    .frame(width: 48)
            }
            .frame(maxWidth: .infinity)

            FlowStepSlider(viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.top, 4)
        }
        .padding(.horizontal, 4)
        .padding(.horizontal, -12)
        .onAppear { viewModel.loadFromStore() }
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
