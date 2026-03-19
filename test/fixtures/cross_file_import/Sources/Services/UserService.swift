import Foundation

actor UserService {
    private var users: [Int] = []

    func addUser(id: Int) {
        users.append(id)
    }

    func count() -> Int {
        return users.count
    }

    subscript(index: Int) -> Int {
        return users[index]
    }
}

enum ServiceError: Error {
    case notFound(id: Int)
    case unauthorized
}
