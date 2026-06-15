/// Seam that lets outer layers resolve repositories without knowing their
/// concrete implementations. The App layer supplies a live provider; the
/// Presentation layer consumes it.
public protocol RepositoryProvider: Sendable {
    var todos: any TodoRepository { get }
}
