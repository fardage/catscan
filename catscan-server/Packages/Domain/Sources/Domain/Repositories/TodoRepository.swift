import struct Foundation.UUID

/// Abstraction over todo persistence. Implemented by the Data layer; the
/// dependency rule keeps Domain unaware of any concrete database.
public protocol TodoRepository: Sendable {
    func all() async throws -> [Todo]
    func create(_ todo: Todo) async throws -> Todo
    func delete(id: UUID) async throws
}
