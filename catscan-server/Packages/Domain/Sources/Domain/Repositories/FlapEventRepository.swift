import struct Foundation.UUID

/// Abstraction over flap-event persistence. Implemented by the Data layer; the
/// dependency rule keeps Domain unaware of any concrete database.
public protocol FlapEventRepository: Sendable {
    func all() async throws -> [FlapEvent]
    func create(_ event: FlapEvent) async throws -> FlapEvent
    func delete(id: UUID) async throws
}
