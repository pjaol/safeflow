import SwiftUI

// MARK: - FlowStepSlider
//
// A horizontal 4-stop step slider for logging flow intensity.
// Sits below the dartboard — always visible, no phase gate.
// Tapping a stop commits immediately. Drag across stops for quick selection.
// Tap the selected stop again to deselect (clear flow).

struct FlowStepSlider: View {
    @ObservedObject var viewModel: DartboardViewModel

    private let levels     = FlowIntensity.allCases
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let stopSize: CGFloat = 42

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let spacing    = totalWidth / CGFloat(levels.count - 1)

                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(AppTheme.Colors.secondaryPink.opacity(0.25))
                        .frame(height: 5)
                        .padding(.horizontal, stopSize / 2)
                        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)

                    // Filled track up to selected stop
                    if let flow = viewModel.committedFlow,
                       let idx = levels.firstIndex(of: flow), idx > 0 {
                        Capsule()
                            .fill(AppTheme.Colors.secondaryPink.opacity(0.8))
                            .frame(width: spacing * CGFloat(idx), height: 5)
                            .padding(.leading, stopSize / 2)
                    }

                    // Stops
                    HStack(spacing: 0) {
                        ForEach(Array(levels.enumerated()), id: \.element) { idx, level in
                            let isSelected = viewModel.committedFlow == level
                            ZStack {
                                Circle()
                                    .fill(isSelected
                                          ? AppTheme.Colors.secondaryPink
                                          : Color.white)
                                    .frame(width: stopSize, height: stopSize)
                                    .shadow(color: AppTheme.Colors.secondaryPink.opacity(isSelected ? 0.55 : 0.0),
                                            radius: isSelected ? 12 : 0,
                                            x: 0, y: isSelected ? 4 : 0)
                                    .shadow(color: .black.opacity(0.18),
                                            radius: 5, x: 0, y: 3)
                                    .overlay(
                                        Circle().strokeBorder(
                                            AppTheme.Colors.secondaryPink.opacity(isSelected ? 0 : 0.4),
                                            lineWidth: 1.5)
                                    )

                                Image(systemName: flowSymbol(for: level))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(isSelected ? .white : AppTheme.Colors.secondaryPink)
                            }
                            .scaleEffect(isSelected ? 1.12 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: viewModel.committedFlow)
                            .onTapGesture { selectLevel(level) }

                            if idx < levels.count - 1 {
                                Spacer()
                            }
                        }
                    }
                }
                // Drag across the slider
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .local)
                        .onChanged { value in
                            let x = value.location.x.clamped(to: 0...totalWidth)
                            let idx = Int((x / totalWidth * CGFloat(levels.count - 1)).rounded())
                            let candidate = levels[idx.clamped(to: 0...(levels.count - 1))]
                            if candidate != viewModel.committedFlow {
                                selectLevel(candidate)
                            }
                        }
                )
            }
            .frame(height: stopSize + 4)

            // Labels
            HStack {
                ForEach(Array(levels.enumerated()), id: \.element) { idx, level in
                    let isSelected = viewModel.committedFlow == level
                    Text(level.localizedName)
                        .font(.system(size: 11, weight: isSelected ? .black : .bold, design: .rounded))
                        .foregroundStyle(isSelected
                                         ? AppTheme.Colors.secondaryPink
                                         : Color(.label).opacity(0.55))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Flow intensity")
        .accessibilityValue(viewModel.committedFlow?.localizedName ?? "Not logged")
        .accessibilityAdjustableAction { direction in
            adjustFlow(direction)
        }
    }

    private func selectLevel(_ level: FlowIntensity) {
        if viewModel.committedFlow == level {
            viewModel.commitFlow(nil)
        } else {
            softImpact.impactOccurred()
            viewModel.commitFlow(level)
        }
    }

    private func flowSymbol(for flow: FlowIntensity) -> String {
        switch flow {
        case .spotting: return "drop.circle"
        case .light:    return "drop.fill"
        case .medium:   return "humidity.fill"
        case .heavy:    return "water.waves"
        }
    }

    private func adjustFlow(_ direction: AccessibilityAdjustmentDirection) {
        let index = viewModel.committedFlow.flatMap { levels.firstIndex(of: $0) } ?? -1
        switch direction {
        case .increment:
            let next = min(index + 1, levels.count - 1)
            viewModel.commitFlow(levels[next])
        case .decrement:
            if index <= 0 { viewModel.commitFlow(nil) }
            else { viewModel.commitFlow(levels[index - 1]) }
        @unknown default: break
        }
    }
}

// MARK: - Comparable clamping helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    let store = CycleStore()
    let vm    = DartboardViewModel(cycleStore: store)
    return FlowStepSlider(viewModel: vm)
        .padding(32)
        .background(AppTheme.Colors.background)
}
