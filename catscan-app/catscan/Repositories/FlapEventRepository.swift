import Foundation
import CatscanAPI

protocol FlapEventRepository: Sendable {
    func getFlapEvents() async throws -> [Components.Schemas.FlapEvent]
    func deleteFlapEvent(id: String) async throws
    /// Lightweight reachability check. Returns the number of events the server
    /// currently reports, or throws if the server can't be reached.
    func checkConnection() async throws -> Int
}

