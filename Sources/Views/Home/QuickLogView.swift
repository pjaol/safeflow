import SwiftUI

/// Bottom sheet presented when the user taps "Period started".
/// Lets them pick a flow intensity in one tap, or dismiss to default to .light.
struct QuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cycleStore: CycleStore

    var body: some View {
        VStack(spacing: AppTheme.Metrics.standardSpacing) {
            handle

            Text("How heavy is your flow?")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)
                .padding(.top, 8)

            flowGrid

            Button("Skip") {
                logPeriodStart(flow: .light)
            }
            .font(AppTheme.Typography.captionFont)
            .foregroundColor(AppTheme.Colors.mediumGrayText)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, AppTheme.Metrics.cardPadding)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.hidden)
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(AppTheme.Colors.mediumGrayText.opacity(0.3))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
    }

    private var flowGrid: some View {
        HStack(spacing: 12) {
            ForEach(FlowIntensity.allCases, id: \.self) { flow in
                FlowButton(flow: flow) {
                    logPeriodStart(flow: flow)
                }
            }
        }
    }

    private func logPeriodStart(flow: FlowIntensity) {
        let today = Calendar.current.startOfDay(for: Date())
        let day = CycleDay(date: today, flow: flow)
        cycleStore.addOrUpdateDay(day)
        dismiss()
    }
}

private struct FlowButton: View {
    let flow: FlowIntensity
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(flow.emoji)
                    .font(.system(size: 28))
                Text(flow.localizedName)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(AppTheme.Colors.deepGrayText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.Colors.secondaryPink.opacity(0.2))
            .cornerRadius(AppTheme.Metrics.cornerRadius)
        }
        .accessibilityIdentifier("quickLog.flow.\(flow.rawValue)")
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        QuickLogView(cycleStore: CycleStore())
    }
}
