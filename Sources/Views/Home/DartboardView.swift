import SwiftUI

// MARK: - DartboardView
//
// Tap any segment to toggle it on/off. Selected segments invert to white
// with a spring bounce so the state change is impossible to miss.
// The centre bullseye is a long-press to open a notes sheet.

struct DartboardView: View {
    @ObservedObject var viewModel: DartboardViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingNotes = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(viewModel.currentItems.enumerated()), id: \.element.id) { index, item in
                    DartboardSegment(
                        index:     index,
                        item:      item,
                        viewModel: viewModel,
                        size:      geo.size
                    )
                }

                NotesBullseye(viewModel: viewModel)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            // Board-level shadow lifts the whole ring off the background
            .shadow(color: .black.opacity(0.13), radius: 18, x: 0, y: 6)
            .shadow(color: .black.opacity(0.07), radius: 4,  x: 0, y: 2)
            .onAppear { viewModel.boardSize = geo.size }
            .onChange(of: geo.size) { _, s in viewModel.boardSize = s }
            .id(viewModel.selectedCategory)
            .transition(reduceMotion
                ? .opacity
                : .opacity.combined(with: .scale(scale: 0.94)))
            .animation(
                reduceMotion ? .none : .easeInOut(duration: 0.22),
                value: viewModel.selectedCategory)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(minWidth: 300, minHeight: 300)
    }
}

// MARK: - DartboardSegment

struct DartboardSegment: View {
    let index:     Int
    let item:      DartboardItem
    @ObservedObject var viewModel: DartboardViewModel
    let size: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bouncing = false

    private var isActive: Bool { viewModel.isItemActive(item) }
    private var category: DartboardCategory { viewModel.selectedCategory }

    private var shape: SegmentShape {
        SegmentShape(
            index:     index,
            itemCount: viewModel.currentItems.count,
            gapDeg:    viewModel.segmentGapDegrees,
            innerFrac: viewModel.innerRadiusFraction,
            outerFrac: viewModel.outerRadiusFraction,
            size:      size
        )
    }

    var body: some View {
        ZStack {
            // Idle: saturated color fill, white text
            // Active: white fill, colored text/icon — unmistakably different
            shape
                .fill(isActive ? Color.white : category.color.opacity(0.78))
                .shadow(
                    color: isActive
                        ? category.color.opacity(0.45)
                        : Color.black.opacity(0.10),
                    radius: isActive ? 12 : 4,
                    x: 0,
                    y: isActive ? 4 : 2
                )

            segmentLabel
        }
        .scaleEffect(bouncing ? 1.08 : 1.0, anchor: .center)
        .contentShape(shape)
        .onTapGesture { handleTap() }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isActive)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: bouncing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.label)
        .accessibilityHint(isActive ? "Logged. Tap to remove." : "Tap to log \(item.label).")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private func handleTap() {
        // Spring bounce
        bouncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { bouncing = false }
        // Haptic
        UIImpactFeedbackGenerator(style: isActive ? .light : .medium).impactOccurred()
        viewModel.toggleItem(item)
        viewModel.commitSelection()
    }

    @ViewBuilder
    private var segmentLabel: some View {
        let mid    = viewModel.midAngle(for: index)
        let maxR   = min(size.width, size.height) / 2
        let innerR = maxR * viewModel.innerRadiusFraction
        let outerR = maxR * viewModel.outerRadiusFraction
        let labelR = innerR + (outerR - innerR) * 0.55
        let rad    = mid * Double.pi / 180.0
        let cx     = size.width  / 2
        let cy     = size.height / 2
        let lx     = cx + CGFloat(Foundation.cos(rad)) * labelR
        let ly     = cy + CGFloat(Foundation.sin(rad)) * labelR

        // Idle: white. Active: saturated category color (inverted from fill)
        let contentColor: Color = isActive ? category.color : .white

        VStack(spacing: 3) {
            Image(systemName: item.sfSymbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(contentColor)
            Text(item.label)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(contentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 64)
                .multilineTextAlignment(.center)
        }
        .position(x: lx, y: ly)
        .allowsHitTesting(false)
    }
}

// MARK: - NotesBullseye

struct NotesBullseye: View {
    @ObservedObject var viewModel: DartboardViewModel
    @State private var showingNotes = false
    @State private var pressing = false

    private var hasNotes: Bool { !viewModel.committedNotes.isEmpty }

    var body: some View {
        ZStack {
            // Outer ring — always visible against the dartboard background
            Circle()
                .strokeBorder(
                    hasNotes ? AppTheme.Colors.primaryBlue : Color.white.opacity(0.7),
                    lineWidth: 2)
                .frame(width: 42, height: 42)

            Circle()
                .fill(hasNotes
                      ? AppTheme.Colors.primaryBlue.opacity(0.85)
                      : Color.white)
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 3)
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                .scaleEffect(pressing ? 1.12 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressing)

            Image(systemName: hasNotes ? "note.text" : "pencil")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(hasNotes
                                 ? .white
                                 : AppTheme.Colors.primaryBlue)
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: 0.4, pressing: { active in
            pressing = active
            if active { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        }, perform: {
            showingNotes = true
        })
        .accessibilityLabel(hasNotes ? "Edit note" : "Add note")
        .accessibilityHint("Long press to open notes")
        .sheet(isPresented: $showingNotes) {
            NotesSheet(viewModel: viewModel)
        }
    }
}

// MARK: - NotesSheet

struct NotesSheet: View {
    @ObservedObject var viewModel: DartboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How are you feeling today?")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .font(.system(.body, design: .rounded))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )

                Spacer()
            }
            .padding()
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.commitNotes(text)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear { text = viewModel.committedNotes }
        .presentationDetents([.medium])
    }
}

// MARK: - SegmentShape

struct SegmentShape: Shape {
    let index:     Int
    let itemCount: Int
    let gapDeg:    Double
    let innerFrac: CGFloat
    let outerFrac: CGFloat
    let size:      CGSize

    func path(in rect: CGRect) -> Path {
        let cx      = size.width  / 2
        let cy      = size.height / 2
        let maxR    = min(size.width, size.height) / 2
        let innerR  = maxR * innerFrac
        let outerR  = maxR * outerFrac

        let slotDeg = 360.0 / Double(itemCount)
        let halfGap = gapDeg / 2.0
        let start   = -90.0 + Double(index) * slotDeg + halfGap
        let end     = start + slotDeg - gapDeg
        let startR  = start * Double.pi / 180.0
        let endR    = end   * Double.pi / 180.0

        let center  = CGPoint(x: cx, y: cy)
        var path    = Path()
        path.addArc(center: center, radius: outerR,
                    startAngle: .radians(startR), endAngle: .radians(endR), clockwise: false)
        path.addArc(center: center, radius: innerR,
                    startAngle: .radians(endR), endAngle: .radians(startR), clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    let store = CycleStore()
    let vm    = DartboardViewModel(cycleStore: store)
    return DartboardView(viewModel: vm)
        .frame(width: 280, height: 280)
        .padding()
        .background(AppTheme.Colors.background)
}
