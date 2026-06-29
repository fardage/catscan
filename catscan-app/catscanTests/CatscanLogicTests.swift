//
//  CatscanLogicTests.swift
//  catscanTests
//
//  Unit tests for the pure logic behind the flap-events dashboard: URL
//  normalization / resolution, view-model derived data, and the settings
//  connection test. These avoid the UI and the network entirely.
//

import Testing
import Foundation
import CatscanAPI
@testable import catscan

// MARK: - Shared helpers

private func event(_ id: String, _ timestamp: Date, image: String? = nil) -> FlapEvent {
    FlapEvent(id: id, timestamp: timestamp, imagePath: image)
}

/// A throwaway, empty `UserDefaults` suite that backs a `SettingsStore` so tests
/// start clean and never touch the shared standard defaults.
private func isolatedDefaults() -> UserDefaults {
    let name = "catscanTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

// MARK: - AppEnvironment.normalizedURL

struct AppEnvironmentURLTests {
    @Test func rejectsEmptyOrWhitespace() {
        #expect(AppEnvironment.normalizedURL(from: "") == nil)
        #expect(AppEnvironment.normalizedURL(from: "   ") == nil)
    }

    @Test func prependsHTTPSWhenSchemeMissing() throws {
        let url = try #require(AppEnvironment.normalizedURL(from: "example.com"))
        #expect(url.scheme == "https")
        #expect(url.host() == "example.com")
    }

    @Test func keepsExplicitScheme() throws {
        let url = try #require(AppEnvironment.normalizedURL(from: "http://localhost:8080"))
        #expect(url.scheme == "http")
        #expect(url.host() == "localhost")
        #expect(url.port == 8080)
    }

    @Test func trimsSurroundingWhitespace() throws {
        let url = try #require(AppEnvironment.normalizedURL(from: "  https://example.com  "))
        #expect(url.host() == "example.com")
    }

    @Test func rejectsURLWithoutHost() {
        #expect(AppEnvironment.normalizedURL(from: "https://") == nil)
    }
}

// MARK: - SettingsStore.imageURL

@MainActor
struct SettingsStoreImageURLTests {
    private func store(server: String = "") -> SettingsStore {
        let store = SettingsStore(defaults: isolatedDefaults())
        store.serverURLString = server
        return store
    }

    @Test func returnsNilWhenNoServerConfigured() {
        #expect(store().imageURL(for: "/images/x.jpg") == nil)
    }

    @Test func returnsNilForMissingOrEmptyPath() {
        let store = store(server: "https://host.example")
        #expect(store.imageURL(for: nil) == nil)
        #expect(store.imageURL(for: "") == nil)
    }

    @Test func resolvesAgainstServerRoot() {
        #expect(store(server: "https://host.example").imageURL(for: "/images/x.jpg")?.absoluteString
                == "https://host.example/images/x.jpg")
    }

    @Test func preservesConfiguredSubpath() {
        // Regression guard: an absolute imagePath must not drop the server's
        // base path (otherwise images diverge from where the API client looks).
        #expect(store(server: "https://host.example/catscan").imageURL(for: "/images/x.jpg")?.absoluteString
                == "https://host.example/catscan/images/x.jpg")
    }
}

// MARK: - SettingsStore persistence

@MainActor
struct SettingsStoreTests {
    @Test func persistsAndReloadsFromDefaults() {
        let defaults = isolatedDefaults()
        let store = SettingsStore(defaults: defaults)
        store.serverURLString = "https://host.example"
        store.streamURLString = "https://cam.example/index.m3u8"

        // A fresh store over the same suite sees the persisted values.
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.serverURLString == "https://host.example")
        #expect(reloaded.streamURLString == "https://cam.example/index.m3u8")
    }

    @Test func clearingAValueRemovesItFromDefaults() {
        let defaults = isolatedDefaults()
        let store = SettingsStore(defaults: defaults)
        store.streamURLString = "https://cam.example/index.m3u8"
        store.streamURLString = "   "   // emptied by the user

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.streamURLString == "")
        #expect(reloaded.streamURL == nil)
    }
}

// MARK: - FlapEventsViewModel derived data

@MainActor
struct FlapEventsViewModelTests {
    private func loaded(_ events: [FlapEvent]) async -> FlapEventsViewModel {
        let viewModel = FlapEventsViewModel(
            repository: PreviewFlapEventRepository(events: events),
            settings: SettingsStore(defaults: isolatedDefaults())
        )
        await viewModel.load()
        return viewModel
    }

    @Test func loadSortsNewestFirstAndCounts() async {
        let now = Date.now
        let events = [
            event("old", now.addingTimeInterval(-7200)),
            event("new", now),
            event("mid", now.addingTimeInterval(-3600)),
        ]
        let viewModel = await loaded(events)
        #expect(viewModel.events.map(\.id) == ["new", "mid", "old"])
        #expect(viewModel.totalCount == 3)
        #expect(viewModel.loadFailed == false)
    }

    @Test func latestEventWithImageSkipsNilAndEmptyPaths() async {
        let now = Date.now
        let cal = Calendar.current
        let events = [
            event("newest-nil", now, image: nil),
            event("empty", cal.date(byAdding: .hour, value: -1, to: now)!, image: ""),
            event("hasImage", cal.date(byAdding: .day, value: -1, to: now)!, image: "/images/x.jpg"),
            event("older", cal.date(byAdding: .day, value: -2, to: now)!, image: "/images/y.jpg"),
        ]
        let viewModel = await loaded(events)
        #expect(viewModel.latestEventWithImage?.id == "hasImage")
    }

    @Test func latestEventWithImageNilWhenNoneHaveImages() async {
        let now = Date.now
        let events = [
            event("a", now, image: nil),
            event("b", now.addingTimeInterval(-3600), image: ""),
        ]
        let viewModel = await loaded(events)
        #expect(viewModel.latestEventWithImage == nil)
    }

    @Test func recentEventsReturnsAtMostFourNewestFirst() async {
        let now = Date.now
        let events = (0..<7).map { event("e\($0)", now.addingTimeInterval(Double(-$0) * 3600)) }
        let viewModel = await loaded(events)
        #expect(viewModel.recentEvents.count == 4)
        #expect(viewModel.recentEvents.map(\.id) == ["e0", "e1", "e2", "e3"])
    }

    @Test func todayCountCountsOnlyTodaysEvents() async {
        let cal = Calendar.current
        let now = Date.now
        let events = [
            event("now", now),
            event("midnight", cal.startOfDay(for: now)),
            event("threeDaysAgo", cal.date(byAdding: .day, value: -3, to: now)!),
        ]
        let viewModel = await loaded(events)
        #expect(viewModel.todayCount == 2)
    }

    @Test func weekCountExcludesEventsBeforeThisWeek() async {
        let now = Date.now
        let events = [
            event("thisWeek", now),
            event("longAgo", Calendar.current.date(byAdding: .day, value: -30, to: now)!),
        ]
        let viewModel = await loaded(events)
        #expect(viewModel.weekCount == 1)
    }

    @Test func eventsByDayGroupsByCalendarDayNewestFirst() async {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: .now)
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: startToday)!
        let fourDaysAgo = cal.date(byAdding: .day, value: -4, to: startToday)!
        let morning = twoDaysAgo.addingTimeInterval(9 * 3600)
        let afternoon = twoDaysAgo.addingTimeInterval(15 * 3600)
        let events = [
            event("today", startToday),
            event("morning", morning),
            event("afternoon", afternoon),
            event("four", fourDaysAgo.addingTimeInterval(12 * 3600)),
        ]
        let groups = await loaded(events).eventsByDay

        #expect(groups.count == 3)
        #expect(groups.map(\.day) == [startToday, twoDaysAgo, fourDaysAgo])
        // Within the busiest day, the later event comes first.
        #expect(groups[1].events.map(\.id) == ["afternoon", "morning"])
    }
}

// MARK: - SettingsViewModel

@MainActor
struct SettingsViewModelTests {
    @Test func testConnectionSuccessReportsEventCount() async {
        let viewModel = SettingsViewModel(
            store: SettingsStore(defaults: isolatedDefaults()),
            makeRepository: { _ in
                PreviewFlapEventRepository(events: [
                    event("1", .now), event("2", .now), event("3", .now),
                ])
            }
        )
        viewModel.draft = "https://example.com"
        await viewModel.testConnection()

        guard case .success(let count) = viewModel.testState else {
            Issue.record("expected .success, got \(viewModel.testState)")
            return
        }
        #expect(count == 3)
    }

    @Test func testConnectionFailureSurfacesLocalizedMessage() async {
        let viewModel = SettingsViewModel(
            store: SettingsStore(defaults: isolatedDefaults()),
            makeRepository: { _ in FailingRepository() }
        )
        viewModel.draft = "https://example.com"
        await viewModel.testConnection()

        guard case .failure(let message) = viewModel.testState else {
            Issue.record("expected .failure, got \(viewModel.testState)")
            return
        }
        #expect(message == "Boom happened")
    }

    @Test func testConnectionDiscardsResultWhenDraftChangesMidFlight() async {
        let gate = Gate()
        let viewModel = SettingsViewModel(
            store: SettingsStore(defaults: isolatedDefaults()),
            makeRepository: { _ in GatedRepository(count: 7, gate: gate) }
        )
        viewModel.draft = "https://a.example"

        let task = Task { await viewModel.testConnection() }
        await gate.waitUntilStarted()   // the request for a.example is now in flight
        viewModel.draft = "https://b.example"   // user retargets the field
        await gate.release()            // let the stale request finish
        await task.value

        // The result described a.example, which is no longer the draft, so it
        // must be discarded rather than shown as "Connected · 7 events".
        #expect(viewModel.testState.isTesting)
        if case .success = viewModel.testState {
            Issue.record("stale connection result was applied to the new draft")
        }
    }

    @Test func saveNormalizesAndPersists() {
        let store = SettingsStore(defaults: isolatedDefaults())
        let viewModel = SettingsViewModel(store: store)
        viewModel.draft = "example.com"

        #expect(viewModel.canSave)
        #expect(viewModel.save())
        #expect(store.serverURLString == "https://example.com")
        #expect(store.serverURL?.absoluteString == "https://example.com")
    }

    @Test func cannotSaveInvalidDraft() {
        let viewModel = SettingsViewModel(store: SettingsStore(defaults: isolatedDefaults()))
        viewModel.draft = "   "

        #expect(!viewModel.canSave)
        #expect(!viewModel.save())
    }
}

// MARK: - Test doubles

private enum SampleError: LocalizedError {
    case boom
    var errorDescription: String? { "Boom happened" }
}

private struct FailingRepository: FlapEventRepository {
    func getFlapEvents() async throws -> [FlapEvent] { throw SampleError.boom }
    func deleteFlapEvent(id: String) async throws { throw SampleError.boom }
    func checkConnection() async throws -> Int { throw SampleError.boom }
}

/// Lets a test observe when an async call has started and hold it open until the
/// test chooses to release it — used to interleave a draft edit with an
/// in-flight connection test deterministically.
private actor Gate {
    private var hasStarted = false
    private var hasReleased = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func markStarted() {
        hasStarted = true
        startContinuation?.resume()
        startContinuation = nil
    }

    func waitUntilStarted() async {
        if hasStarted { return }
        await withCheckedContinuation { startContinuation = $0 }
    }

    func release() {
        hasReleased = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func waitForRelease() async {
        if hasReleased { return }
        await withCheckedContinuation { releaseContinuation = $0 }
    }
}

private struct GatedRepository: FlapEventRepository {
    let count: Int
    let gate: Gate

    func getFlapEvents() async throws -> [FlapEvent] { [] }
    func deleteFlapEvent(id: String) async throws {}
    func checkConnection() async throws -> Int {
        await gate.markStarted()
        await gate.waitForRelease()
        return count
    }
}
