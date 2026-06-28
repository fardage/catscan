import Foundation
import CatscanAPI
import OpenAPIURLSession

actor RemoteFlapEventRepository: FlapEventRepository {
    private let client: Client

    init(serverURL: URL) {
        client = Client(serverURL: serverURL, transport: URLSessionTransport())
    }

    func getFlapEvents() async throws -> [Components.Schemas.FlapEvent] {
        let response = try await client.listFlapEvents()
        switch response {
        case .ok(let ok):
            switch ok.body {
            case .json(let events): return events
            }
        case .undocumented(let statusCode, _):
            throw RepositoryError.unexpectedStatus(statusCode)
        }
    }

    func deleteFlapEvent(id: String) async throws {
        let response = try await client.deleteFlapEvent(path: .init(id: id))
        switch response {
        case .noContent: return
        case .undocumented(let statusCode, _):
            throw RepositoryError.unexpectedStatus(statusCode)
        }
    }

    func checkConnection() async throws -> Int {
        try await getFlapEvents().count
    }
}

private enum RepositoryError: LocalizedError {
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let code):
            return "The server returned an unexpected status (\(code))."
        }
    }
}
