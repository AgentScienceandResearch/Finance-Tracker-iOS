import Foundation

class GitHubService: NSObject, ObservableObject {
    static let shared = GitHubService()
    
    let githubToken = AppConfig.shared.gitHubToken
    let baseURL = "https://api.github.com"
    
    @Published var isLoading = false
    @Published var error: String?
    
    // MARK: - Get User Info
    func getUserInfo(username: String) async throws -> GitHubUser? {
        guard !username.isEmpty else { return nil }
        
        let url = URL(string: "\(baseURL)/users/\(username)")!
        var request = URLRequest(url: url)
        
        if !githubToken.isEmpty {
            request.setValue("token \(githubToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubUser.self, from: data)
    }
    
    // MARK: - Get Repositories
    func getRepositories(username: String, sort: String = "updated") async throws -> [GitHubRepository]? {
        guard !username.isEmpty else { return nil }
        
        let url = URL(string: "\(baseURL)/users/\(username)/repos?sort=\(sort)&per_page=30")!
        var request = URLRequest(url: url)
        
        if !githubToken.isEmpty {
            request.setValue("token \(githubToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([GitHubRepository].self, from: data)
    }
    
    // MARK: - Get Repository Details
    func getRepository(owner: String, repo: String) async throws -> GitHubRepository? {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)")!
        var request = URLRequest(url: url)
        
        if !githubToken.isEmpty {
            request.setValue("token \(githubToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubRepository.self, from: data)
    }
    
    // MARK: - Get Repository Releases
    func getReleases(owner: String, repo: String) async throws -> [GitHubRelease]? {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/releases")!
        var request = URLRequest(url: url)
        
        if !githubToken.isEmpty {
            request.setValue("token \(githubToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([GitHubRelease].self, from: data)
    }
    
    // MARK: - Get Repository Languages
    func getLanguages(owner: String, repo: String) async throws -> [String: Int]? {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/languages")!
        var request = URLRequest(url: url)
        
        if !githubToken.isEmpty {
            request.setValue("token \(githubToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        return try JSONDecoder().decode([String: Int].self, from: data)
    }
}

// MARK: - Models
struct GitHubUser: Codable, Identifiable {
    let id: Int
    let login: String
    let name: String?
    let bio: String?
    let publicRepos: Int
    let followers: Int
    let following: Int
    let avatarUrl: String?
    let profileUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, login, name, bio
        case publicRepos = "publicRepos"
        case followers, following
        case avatarUrl = "avatarUrl"
        case profileUrl = "profileUrl"
    }
}

struct GitHubRepository: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String?
    let description: String?
    let url: String?
    let stargazersCount: Int
    let forksCount: Int
    let watchersCount: Int
    let language: String?
    let topics: [String]?
    let createdAt: Date?
    let updatedAt: Date?
    let pushedAt: Date?
    let homepageUrl: String?
    let isPrivate: Bool?
    let isFork: Bool?
    let visibility: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "fullName"
        case description, url
        case stargazersCount = "stargazersCount"
        case forksCount = "forksCount"
        case watchersCount = "watchersCount"
        case language, topics
        case createdAt = "createdAt"
        case updatedAt = "updatedAt"
        case pushedAt = "pushedAt"
        case homepageUrl = "homepageUrl"
        case isPrivate = "isPrivate"
        case isFork = "isFork"
        case visibility
    }
}

struct GitHubRelease: Codable, Identifiable {
    let id: Int
    let tagName: String?
    let name: String?
    let body: String?
    let draftRelease: Bool?
    let prerelease: Bool?
    let createdAt: Date?
    let publishedAt: Date?
    let tarballUrl: String?
    let zipballUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tagName"
        case name, body
        case draftRelease = "draftRelease"
        case prerelease
        case createdAt = "createdAt"
        case publishedAt = "publishedAt"
        case tarballUrl = "tarballUrl"
        case zipballUrl = "zipballUrl"
    }
}

// MARK: - Network Error
enum NetworkError: LocalizedError {
    case invalidResponse
    case decodingError
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let message):
            return message
        }
    }
}
