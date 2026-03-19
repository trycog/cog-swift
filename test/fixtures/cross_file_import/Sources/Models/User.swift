import Foundation

/// A user in the system.
class User {
    let id: Int
    var name: String
    var email: String

    init(id: Int, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }

    static func guest() -> User {
        return User(id: 0, name: "Guest", email: "")
    }
}
