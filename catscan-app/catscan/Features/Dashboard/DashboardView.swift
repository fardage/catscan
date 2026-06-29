import SwiftUI
import CatscanAPI

/// "Summary" home screen: a hero snapshot, at-a-glance
/// stats, and a recent-activity preview that drills into the full history.
struct DashboardView: View {
    @State private var viewModel: FlapEventsViewModel
    @State private var showingSettings = false

    @MainActor
    init(viewModel: FlapEventsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.top, 4)

                    liveStreamCard
                    heroCard
                    statsSection
                    recentActivitySection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .containerRelativeFrame(.horizontal)
            }
            .screenBackground()
            .navigationTitle(L10n.Dashboard.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await viewModel.load() }
                        } label: {
                            Label(L10n.Dashboard.refresh, systemImage: "arrow.clockwise")
                        }
                        Button {
                            showingSettings = true
                        } label: {
                            Label(L10n.Dashboard.serverSettings, systemImage: "server.rack")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(store: viewModel.settings)
            }
            .refreshable { await viewModel.load() }
            .task {
                if viewModel.events.isEmpty { await viewModel.load() }
            }
        }
    }

    // MARK: - Live stream

    /// Shows the camera's live feed when a stream URL is configured; renders
    /// nothing otherwise so the dashboard collapses cleanly.
    @ViewBuilder
    private var liveStreamCard: some View {
        if let url = viewModel.settings.streamURL {
            VStack(alignment: .leading, spacing: 0) {
                Label(L10n.Dashboard.liveStream, systemImage: "dot.radiowaves.left.and.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.vibrantCoral)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                LiveStreamView(url: url, isActive: !showingSettings)
                    .frame(height: 220)
                    .clipped()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroCard: some View {
        if let event = viewModel.latestEventWithImage {
            let imageURL = viewModel.settings.imageURL(for: event.imagePath)
            NavigationLink {
                FlapEventDetailView(event: event, imageURL: imageURL)
            } label: {
                LatestSnapshotCard(event: event, imageURL: imageURL)
            }
            .buttonStyle(.plain)
        } else {
            LatestSnapshotCard(event: nil, imageURL: nil, isLoading: viewModel.isLoading,
                               loadFailed: viewModel.loadFailed)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(title: L10n.Dashboard.statToday, value: viewModel.todayCount,
                     systemImage: "sun.max.fill", tint: .sunlitClay)
            StatCard(title: L10n.Dashboard.statThisWeek, value: viewModel.weekCount,
                     systemImage: "calendar", tint: .vibrantCoral)
            StatCard(title: L10n.Dashboard.statTotal, value: viewModel.totalCount,
                     systemImage: "pawprint.fill", tint: .gunmetal)
        }
    }

    // MARK: - Recent activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Dashboard.recentActivity)
                    .font(.title3.bold())
                Spacer()
                if !viewModel.events.isEmpty {
                    NavigationLink {
                        FlapEventsView(viewModel: viewModel)
                    } label: {
                        Text(L10n.Dashboard.showAll)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }

            if viewModel.events.isEmpty {
                emptyActivityCard
            } else {
                EventListCard(viewModel: viewModel, events: viewModel.recentEvents)
            }
        }
    }

    private var emptyActivityCard: some View {
        HStack(spacing: 12) {
            Image(systemName: emptyActivitySymbol)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(emptyActivityMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var emptyActivitySymbol: String {
        if viewModel.isLoading { return "hourglass" }
        return viewModel.loadFailed ? "wifi.exclamationmark" : "pawprint"
    }

    private var emptyActivityMessage: LocalizedStringKey {
        if viewModel.isLoading { return L10n.Dashboard.loadingActivity }
        if viewModel.loadFailed { return L10n.Dashboard.activityUnreachable }
        return L10n.Dashboard.noActivity
    }
}

// MARK: - Hero snapshot card

/// Large highlight card showing the most recent captured snapshot.
private struct LatestSnapshotCard: View {
    let event: FlapEvent?
    let imageURL: URL?
    var isLoading: Bool = false
    var loadFailed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(L10n.Dashboard.latestSnapshot, systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.vibrantCoral)
                Spacer()
                if let event {
                    Text(event.timestamp.formatted(.relative(presentation: .named)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ZStack(alignment: .bottomLeading) {
                if let event {
                    RemoteImageView(url: imageURL)
                        .frame(height: 220)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Dashboard.lastSeen)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(16)
                } else {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        VStack(spacing: 8) {
                            Image(systemName: placeholderSymbol)
                                .font(.system(size: 34))
                                .foregroundStyle(.secondary)
                            Text(placeholderMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 220)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var placeholderSymbol: String {
        if isLoading { return "hourglass" }
        return loadFailed ? "wifi.exclamationmark" : "cat"
    }

    private var placeholderMessage: LocalizedStringKey {
        if isLoading { return L10n.Dashboard.snapshotLoading }
        return loadFailed ? L10n.Dashboard.snapshotLoadFailed : L10n.Dashboard.noSnapshots
    }
}

// MARK: - Stat card

/// Compact Health-style metric tile: tinted icon, big number, unit caption.
private struct StatCard: View {
    let title: LocalizedStringKey
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(value)")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)

            Text(L10n.Dashboard.visitUnit(value))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cardStyle()
    }
}

#if DEBUG
#Preview("Dashboard") {
    DashboardView(viewModel: .preview())
}

#Preview("Dashboard – Empty") {
    DashboardView(viewModel: .preview(empty: true))
}
#endif
