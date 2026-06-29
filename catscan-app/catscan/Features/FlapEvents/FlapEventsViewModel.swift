import Foundation
import Observation
import CatscanAPI

@Observable
@MainActor
final class FlapEventsViewModel {
    private(set) var events: [FlapEvent] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false

    private let repository: any FlapEventRepository

    nonisolated init(repository: any FlapEventRepository) {
        self.repository = repository
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            let fetched = try await repository.getFlapEvents()
            events = fetched.sorted { $0.timestamp > $1.timestamp }
        } catch {
            loadFailed = true
            print("FlapEventsViewModel.load error: \(error)")
        }
    }

    func delete(id: String) async {
        try? await repository.deleteFlapEvent(id: id)
        await load()
    }

    // MARK: - Derived data

    /// Most recent event that actually has a captured snapshot, for the hero card.
    /// An empty `imagePath` counts as "no image" (it resolves to no URL), so the
    /// hero falls through to the next event that has a loadable snapshot.
    var latestEventWithImage: FlapEvent? {
        events.first { $0.imagePath?.isEmpty == false }
    }

    /// A short slice of recent events for the dashboard preview list.
    var recentEvents: [FlapEvent] { Array(events.prefix(4)) }

    var totalCount: Int { events.count }

    var todayCount: Int {
        events.filter { Calendar.current.isDateInToday($0.timestamp) }.count
    }

    var weekCount: Int {
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return events.filter { week.contains($0.timestamp) }.count
    }

    /// Events bucketed by calendar day, newest day first — used by the full history.
    var eventsByDay: [DayGroup] {
        let groups = Dictionary(grouping: events) {
            Calendar.current.startOfDay(for: $0.timestamp)
        }
        return groups
            .map { DayGroup(day: $0.key, events: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.day > $1.day }
    }
}

/// A day's worth of flap events.
struct DayGroup: Identifiable {
    let day: Date
    let events: [FlapEvent]
    var id: Date { day }
}

#if DEBUG
/// In-memory repository so SwiftUI previews never touch the network.
struct PreviewFlapEventRepository: FlapEventRepository {
    var events: [FlapEvent]
    func getFlapEvents() async throws -> [FlapEvent] { events }
    func deleteFlapEvent(id: String) async throws {}
    func checkConnection() async throws -> Int { events.count }
}

extension FlapEventsViewModel {
    /// A view model preloaded with believable sample data for previews.
    @MainActor
    static func preview(empty: Bool = false) -> FlapEventsViewModel {
        let now = Date.now
        let sample: [FlapEvent] = empty ? [] : (0..<9).map { i in
            FlapEvent(
                id: UUID().uuidString,
                timestamp: now.addingTimeInterval(Double(-i) * 3.4 * 3600),
                imagePath: i % 4 == 0 ? nil : "/images/sample-\(i).jpg"
            )
        }
        let viewModel = FlapEventsViewModel(repository: PreviewFlapEventRepository(events: sample))
        viewModel.events = sample.sorted { $0.timestamp > $1.timestamp }
        return viewModel
    }
}
#endif
