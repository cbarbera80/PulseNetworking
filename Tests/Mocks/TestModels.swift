import Foundation

struct MockUser: Codable {
    let id: Int
    let name: String
    let email: String
}

struct MockCreateUserRequest: Encodable {
    let name: String
    let email: String
}

struct MockErrorResponse: Codable {
    let error: String
    let message: String
}
