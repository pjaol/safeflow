import SwiftUI

/// Presents the bundled support directory — organisations, helplines, and condition guides.
/// Resources are filtered contextually based on active signals and nudges.
/// All links open via UIApplication.open() — no web views, no tracking, no network calls
/// until the user explicitly taps a link.
struct GetSupportView: View {

    let cycleStore: CycleStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    /// Selected country filter. nil = All.
    @State private var selectedRegion: String? = nil
    /// When true, hide resources with no URL.
    @State private var onlineOnly: Bool = false

    /// Active tags computed once at view creation — used for contextual highlighting.
    /// Kept as a stored property so @MainActor ContentEvaluator isn't called during body renders.
    private let activeTags: [String]

    init(cycleStore: CycleStore) {
        self.cycleStore = cycleStore
        let evaluator = ContentEvaluator(store: cycleStore)
        let dismissed = DismissedNudges.load()
        var tags: [String] = []
        if let nudge = evaluator.activeNudge(dismissed: dismissed) {
            tags += nudge.symptomsAny
        }
        for signal in evaluator.activeSignals(dismissed: dismissed) {
            switch signal.checkType {
            case "cramps_escalating", "cramps_follicular", "severe_cluster":
                tags += ["cramps", "endometriosis", "pelvic_pain"]
            case "heavy_flow_majority":
                tags += ["heavy_flow", "cramps", "irregular"]
            default: break
            }
        }
        self.activeTags = Array(Set(tags))
    }

    /// Region code matching our resources.json conventions, derived from the active app locale.
    /// Maps iOS "GB" → "UK" to match resource region tags.
    private var userRegion: String? {
        let code = locale.region?.identifier.uppercased()
            ?? Locale.current.region?.identifier.uppercased()
        guard let code else { return nil }
        return code == "GB" ? "UK" : code
    }

    /// All distinct non-global regions present in the resource list, sorted for display.
    private var availableRegions: [String] {
        Set(ContentLoader.resources.map { $0.region.uppercased() })
            .filter { $0 != "GLOBAL" }
            .sorted()
    }

    /// Crisis resources pinned to top — filtered by country if a region is selected,
    /// but never filtered by the online-only toggle (phone lines must never be hidden).
    /// Global crisis resources are suppressed when the active region has its own crisis entries,
    /// so locale-specific hotlines always take precedence over English-language global fallbacks.
    private var crisisResources: [ContentResource] {
        let all = ContentLoader.resources.filter {
            $0.tags.contains("crisis") || $0.tags.contains("dv")
        }

        // Determine the effective region: explicit filter selection or device locale
        let effectiveRegion = selectedRegion ?? userRegion

        if let region = effectiveRegion {
            let regional = all.filter { $0.region.uppercased() == region }
            // If locale-specific crisis resources exist, show only those — suppress global fallbacks
            if !regional.isEmpty {
                return regional
            }
            // No regional entries: fall back to global
            return all.filter { $0.region.uppercased() == "GLOBAL" }
        }

        // No region context: show all (regional + global), sorted regional first
        return all.sorted { a, _ in a.region.uppercased() != "GLOBAL" }
    }

    private var nonCrisisGroupedResources: [(category: String, resources: [ContentResource])] {
        let crisisIds = Set(crisisResources.map(\.id))
        var all = ContentLoader.resources.filter { !crisisIds.contains($0.id) }

        // Apply country filter
        let effectiveRegion = selectedRegion ?? userRegion
        if let region = effectiveRegion {
            let regional = all.filter { $0.region.uppercased() == region }
            // Per-category: if a regional entry exists, suppress global entries in that category
            let regionalCategories = Set(regional.map(\.category))
            all = all.filter {
                $0.region.uppercased() == region ||
                ($0.region.uppercased() == "GLOBAL" && !regionalCategories.contains($0.category))
            }
        }

        // Apply online filter: only show resources with a URL
        if onlineOnly {
            all = all.filter { $0.url != nil && !($0.url?.isEmpty ?? true) }
        }

        let tagSet = Set(activeTags)
        let region = userRegion  // e.g. "US", "GB"

        // Sort priority: contextually relevant > locale-region match > global > other regions > alphabetical
        let sorted = all.sorted { a, b in
            let aRelevant = !Set(a.tags).isDisjoint(with: tagSet)
            let bRelevant = !Set(b.tags).isDisjoint(with: tagSet)
            if aRelevant != bRelevant { return aRelevant }

            // Geographic: prefer region match or global over foreign regions
            if let region {
                let aRegionMatch = a.region.uppercased() == region || a.region.uppercased() == "GLOBAL"
                let bRegionMatch = b.region.uppercased() == region || b.region.uppercased() == "GLOBAL"
                if aRegionMatch != bRegionMatch { return aRegionMatch }
            }

            return a.category < b.category
        }

        // Group by category label
        var groups: [(String, [ContentResource])] = []
        var seen: [String: Int] = [:]
        for resource in sorted {
            let label = categoryLabel(resource.category)
            if let idx = seen[label] {
                groups[idx].1.append(resource)
            } else {
                seen[label] = groups.count
                groups.append((label, [resource]))
            }
        }
        return groups
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    disclaimerBanner
                    filterBar

                    // Crisis resources always pinned to top, unaffected by filters
                    if !crisisResources.isEmpty {
                        crisisSection
                    }

                    if nonCrisisGroupedResources.isEmpty {
                        Text("No resources match these filters.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }

                    ForEach(nonCrisisGroupedResources, id: \.category) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(categoryLocalizedLabel(group.category))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.mediumGrayText)
                                .padding(.horizontal, 4)

                            VStack(spacing: 8) {
                                ForEach(group.resources) { resource in
                                    ResourceRow(resource: resource, activeTags: Set(activeTags))
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Get Support")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Pre-select the user's locale region if we have resources for it
                if selectedRegion == nil, let region = userRegion,
                   availableRegions.contains(where: { $0.uppercased() == region }) {
                    selectedRegion = region
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.accentBlue)
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Country chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "All", isActive: selectedRegion == nil) {
                        selectedRegion = nil
                    }
                    ForEach(availableRegions, id: \.self) { region in
                        FilterChip(label: regionLabel(region), isActive: selectedRegion == region) {
                            selectedRegion = selectedRegion == region ? nil : region
                        }
                    }
                }
                .padding(.horizontal, 1)
            }

            // Online toggle
            Button {
                onlineOnly.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: onlineOnly ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(onlineOnly ? AppTheme.Colors.accentBlue : AppTheme.Colors.mediumGrayText)
                    Text("Online resources only")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundColor(onlineOnly ? AppTheme.Colors.accentBlue : AppTheme.Colors.mediumGrayText)
                }
            }
            .accessibilityLabel(onlineOnly ? "Online resources only, on" : "Online resources only, off")
            .accessibilityAddTraits(.isToggle)
        }
    }

    private func regionLabel(_ region: String) -> LocalizedStringKey {
        LocalizedStringKey(region)
    }

    private var crisisSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "heart.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .semibold))
                Text("If you need help now")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(crisisResources) { resource in
                    ResourceRow(resource: resource, activeTags: Set(activeTags))
                }
            }
        }
        .padding(12)
        .background(Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.50, green: 0.15, blue: 0.22, alpha: 1)
                : UIColor(red: 0.72, green: 0.25, blue: 0.32, alpha: 1)
        }))
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("If you need help now. Crisis and safety resources.")
    }

    private var disclaimerBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(AppTheme.Colors.accentBlue)
                .font(.system(size: 16))
            Text("These are independent organisations. Clio Daye does not share your data with them. Links open in your browser.")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGrayText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(AppTheme.Colors.accentBlue.opacity(0.08))
        .cornerRadius(AppTheme.Metrics.cornerRadius)
    }

    private func categoryLabel(_ raw: String) -> String {
        switch raw {
        case "ob_gyn":             return "OB/GYN & Specialist"
        case "pmdd":               return "PMDD & Premenstrual Disorders"
        case "endometriosis":      return "Endometriosis"
        case "pcos":               return "PCOS"
        case "gp":                 return "General Health Info"
        case "crisis":             return "Crisis & Safety"
        case "mental_health":      return "Mental Health"
        case "reproductive_health": return "Reproductive Health"
        case "sexual_health":      return "Sexual Health"
        default:                   return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func categoryLocalizedLabel(_ raw: String) -> LocalizedStringKey {
        LocalizedStringKey(categoryLabel(raw))
    }
}

// MARK: - ResourceRow

private struct ResourceRow: View {
    let resource: ContentResource
    let activeTags: Set<String>

    private var isContextual: Bool {
        !Set(resource.tags).isDisjoint(with: activeTags)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Category icon
            Image(systemName: categoryIcon(resource.category))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(categoryColor(resource.category))
                .frame(width: 34, height: 34)
                .background(categoryColor(resource.category).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(resource.name)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.deepGrayText)

                    if resource.region != "global" {
                        Text(resource.region)
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.background)
                            .cornerRadius(4)
                    }
                }

                Text(resource.shortDescription)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .fixedSize(horizontal: false, vertical: true)

                // Contact row
                HStack(spacing: 12) {
                    if let url = resource.url, !url.isEmpty {
                        LinkButton(label: "Visit", systemImage: "arrow.up.right.square", urlString: url)
                    }
                    if let phone = resource.phone, !phone.isEmpty {
                        LinkButton(label: LocalizedStringKey(phone), systemImage: "phone", urlString: "tel:\(phone.filter { $0.isNumber || $0 == "+" })")
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(isContextual
            ? AppTheme.Colors.accentBlue.opacity(0.06)
            : AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(resource.name). \(resource.shortDescription)")
    }

    private func categoryIcon(_ cat: String) -> String {
        switch cat {
        case "ob_gyn":              return "stethoscope"
        case "pmdd":                return "waveform.path.ecg"
        case "endometriosis":       return "cross.case.fill"
        case "pcos":                return "chart.line.uptrend.xyaxis"
        case "gp":                  return "book.fill"
        case "crisis":              return "heart.circle.fill"
        case "mental_health":       return "brain.head.profile"
        case "reproductive_health": return "person.and.background.dotted"
        default:                    return "info.circle"
        }
    }

    private func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "ob_gyn":              return AppTheme.Colors.accentBlue
        case "pmdd":                return AppTheme.Colors.secondaryPink
        case "endometriosis":       return AppTheme.Colors.secondaryPink
        case "pcos":                return AppTheme.Colors.primaryBlue
        case "gp":                  return AppTheme.Colors.accentBlue
        case "crisis":              return AppTheme.Colors.forecastMood   // amber
        case "mental_health":       return AppTheme.Colors.secondaryPink
        case "reproductive_health": return AppTheme.Colors.primaryBlue
        default:                    return AppTheme.Colors.neutralGray
        }
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let label: LocalizedStringKey
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundColor(isActive ? .white : AppTheme.Colors.deepGrayText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? AppTheme.Colors.accentBlue : AppTheme.Colors.secondaryBackground)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(isActive ? 0.08 : 0.04), radius: 4, x: 0, y: 1)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

// MARK: - LinkButton

private struct LinkButton: View {
    let label: LocalizedStringKey
    let systemImage: String
    let urlString: String

    var body: some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
            .foregroundColor(AppTheme.Colors.accentBlue)
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Preview

#Preview {
    GetSupportView(cycleStore: CycleStore())
}
