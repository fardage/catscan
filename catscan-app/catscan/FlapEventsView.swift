import SwiftUI

/// Full flap-event history, grouped into day sections. Pushed from the
/// dashboard's "Show All" and shares its view model so there's no refetch.
struct FlapEventsView: View {
    let viewModel: FlapEventsViewModel

    var body: some View {
        ScrollView {
            if viewModel.events.isEmpty {
                ContentUnavailableView {
                    Label(viewModel.loadFailed ? "Couldn't Load Activity" : "No Activity",
                          systemImage: viewModel.loadFailed ? "wifi.exclamationmark" : "pawprint")
                } description: {
                    Text(viewModel.loadFailed
                         ? "We couldn't reach your Catscan server. Pull to refresh to try again."
                         : "Flap events will appear here as your cat comes and goes.")
                }
                .padding(.top, 80)
            } else {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel.eventsByDay) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(Self.dayLabel(for: group.day))
                                    .font(.headline)
                                Spacer()
                                Text("^[\(group.events.count) visit](inflect: true)")
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
    }

    private static func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        FlapEventsView(viewModel: .preview())
    }
}
#endif
