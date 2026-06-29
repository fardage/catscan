import SwiftUI

/// Full flap-event history, grouped into day sections. Pushed from the
/// dashboard's "Show All" and shares its view model so there's no refetch.
struct FlapEventsView: View {
    let viewModel: FlapEventsViewModel

    var body: some View {
        ScrollView {
            if viewModel.events.isEmpty {
                ContentUnavailableView {
                    Label(viewModel.loadFailed ? L10n.Activity.failedTitle : L10n.Activity.emptyTitle,
                          systemImage: viewModel.loadFailed ? "wifi.exclamationmark" : "pawprint")
                } description: {
                    Text(viewModel.loadFailed
                         ? L10n.Activity.failedDescription
                         : L10n.Activity.emptyDescription)
                }
                .padding(.top, 80)
            } else {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel.eventsByDay) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Self.dayLabel(for: group.day)
                                    .font(.headline)
                                Spacer()
                                Text(L10n.Activity.visitCount(group.events.count))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 4)

                            EventListCard(events: group.events)
                        }
                    }
                }
                .padding()
            }
        }
        .screenBackground()
        .navigationTitle(L10n.Activity.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
    }

    /// The day-section header. "Today"/"Yesterday" are localized; other days use
    /// the locale-formatted date. Returns `Text` (not `String`) so the localized
    /// keys aren't rendered verbatim.
    private static func dayLabel(for date: Date) -> Text {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return Text(L10n.Common.today) }
        if calendar.isDateInYesterday(date) { return Text(L10n.Common.yesterday) }
        return Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        FlapEventsView(viewModel: .preview())
    }
}
#endif
