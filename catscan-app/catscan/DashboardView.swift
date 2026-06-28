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

                    heroCard
                    statsSection
                    recentActivitySection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .containerRelativeFrame(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await viewModel.load() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Server Settings", systemImage: "server.rack")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .refreshable { await viewModel.load() }
            .task {
                if viewModel.events.isEmpty { await viewModel.load() }
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroCard: some View {
        if let event = viewModel.latestEventWithImage {
            NavigationLink {
                FlapEventDetailView(event: event)
            } label: {
                LatestSnapshotCard(event: event)
            }
            .buttonStyle(.plain)
        } else {
            LatestSnapshotCard(event: nil, isLoading: viewModel.isLoading,
                               loadFailed: viewModel.loadFailed)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Today", value: viewModel.todayCount,
                     systemImage: "sun.max.fill", tint: .orange)
            StatCard(title: "This Week", value: viewModel.weekCount,
                     systemImage: "calendar", tint: .blue)
            StatCard(title: "Total", value: viewModel.totalCount,
                     systemImage: "pawprint.fill", tint: .green)
        }
    }

    // MARK: - Recent activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Activity")
                    .font(.title3.bold())
                Spacer()
                if !viewModel.events.isEmpty {
                    NavigationLink {
                        FlapEventsView(viewModel: viewModel)
                    } label: {
                        Text("Show All")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }

            if viewModel.events.isEmpty {
                emptyActivityCard
            } else {
                EventListCard(events: viewModel.recentEvents)
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

    private var emptyActivityMessage: String {
        if viewModel.isLoading { return "Loading recent activity…" }
        if viewModel.loadFailed {
            return "Couldn't reach your Catscan server. Pull to refresh to try again."
        }
        return "No flap events yet. They'll appear here as your cat comes and goes."
    }
}

// MARK: - Hero snapshot card

/// Large highlight card showing the most recent captured snapshot.
private struct LatestSnapshotCard: View {
    let event: FlapEvent?
    var isLoading: Bool = false
    var loadFailed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Latest Snapshot", systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
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
                    RemoteImageView(url: AppEnvironment.imageURL(for: event.imagePath))
                        .frame(height: 220)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last seen")
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

    private var placeholderMessage: String {
        if isLoading { return "Loading…" }
        return loadFailed ? "Couldn't load snapshot" : "No snapshots yet"
    }
}

// MARK: - Stat card

/// Compact Health-style metric tile: tinted icon, big number, unit caption.
private struct StatCard: View {
    let title: String
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

            Text(value == 1 ? "visit" : "visits")
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
