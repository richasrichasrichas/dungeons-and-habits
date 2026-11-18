// SPDX-License-Identifier: MPL-2.0
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum APIServiceError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case server(statusCode: Int, message: String)
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "URL da API inválida. Confira o endereço em Configurações."
        case .invalidResponse:
            return "A API retornou uma resposta inválida."
        case let .server(statusCode, message):
            return "Erro da API (HTTP \(statusCode)): \(message)"
        case let .transport(message):
            return "Falha de conexão com a API: \(message)"
        case let .decoding(message):
            return "Não foi possível interpretar a resposta da API: \(message)"
        }
    }
}

/// Camada de transporte HTTP. A UI não conhece URLSession nem os detalhes dos endpoints.
actor APIService {
    typealias BaseURLProvider = @Sendable () -> URL?
    typealias TokenProvider = @Sendable () async -> String?

    private let session: URLSession
    private let baseURLProvider: BaseURLProvider
    private let tokenProvider: TokenProvider
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        session: URLSession = .shared,
        baseURLProvider: @escaping BaseURLProvider = { AppConfiguration.currentAPIURL },
        tokenProvider: @escaping TokenProvider = { nil }
    ) {
        self.session = session
        self.baseURLProvider = baseURLProvider
        self.tokenProvider = tokenProvider

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) {
                return date
            }

            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Data ISO-8601 inválida: \(value)"
            )
        }
        self.decoder = decoder
        self.encoder = JSONEncoder()
    }

    func fetchUserSheet(userID: UUID) async throws -> User {
        try await perform(
            User.self,
            path: "/user/\(userID.uuidString)/sheet",
            method: .get
        )
    }

    func fetchPendingQuests(userID: UUID) async throws -> [Quest] {
        try await perform(
            [Quest].self,
            path: "/quests",
            method: .get,
            queryItems: [URLQueryItem(name: "user_id", value: userID.uuidString)]
        )
    }

    func completeQuest(id: UUID) async throws -> QuestCompletion {
        try await perform(
            QuestCompletion.self,
            path: "/quests/\(id.uuidString)/complete",
            method: .post
        )
    }

    func fetchRewards(userID: UUID) async throws -> [Reward] {
        try await perform(
            [Reward].self,
            path: "/rewards",
            method: .get,
            queryItems: [URLQueryItem(name: "user_id", value: userID.uuidString)]
        )
    }

    func buyReward(id: UUID, userID: UUID) async throws -> RewardPurchase {
        let body = try encoder.encode(UserIDBody(userID: userID))
        return try await perform(
            RewardPurchase.self,
            path: "/rewards/\(id.uuidString)/buy",
            method: .post,
            body: body
        )
    }

    private func perform<Response: Decodable>(
        _ responseType: Response.Type,
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Response {
        var request = URLRequest(url: try makeURL(path: path, queryItems: queryItems))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }

        // O token fica centralizado aqui. Quando JWT for adicionado, basta injetar um
        // TokenProvider que leia o token armazenado com segurança.
        if let token = await tokenProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIServiceError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let payload = try? decoder.decode(APIErrorPayload.self, from: data)
            let message = payload?.error ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw APIServiceError.server(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            throw APIServiceError.decoding(error.localizedDescription)
        }
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard let baseURL = baseURLProvider(),
              let scheme = baseURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              baseURL.host != nil,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else {
            throw APIServiceError.invalidBaseURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpoint = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, endpoint].filter { !$0.isEmpty }.joined(separator: "/")

        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }

        guard let url = components.url else {
            throw APIServiceError.invalidBaseURL
        }
        return url
    }
}

private enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

private struct APIErrorPayload: Decodable {
    let error: String?
}

private struct UserIDBody: Encodable {
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
    }
}
