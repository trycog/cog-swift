import Foundation

/// A simple greeter class.
class Greeter {
    /// The name to greet.
    var name: String
    let greeting: String

    init(name: String, greeting: String = "Hello") {
        self.name = name
        self.greeting = greeting
    }

    /// Generate a greeting message.
    func greet() -> String {
        let message = "\(greeting), \(name)!"
        return message
    }

    deinit {
        // cleanup
    }

    subscript(index: Int) -> String {
        return "\(greeting) #\(index)"
    }
}

/// A protocol for things that can speak.
protocol Speakable {
    associatedtype Voice
    func speak() -> String
}

/// Represents a direction.
enum Direction: Int {
    case north
    case south
    case east
    case west

    var opposite: Direction {
        switch self {
        case .north: return .south
        case .south: return .north
        case .east: return .west
        case .west: return .east
        }
    }
}

/// A result type with associated values.
enum Result<T> {
    case success(value: T)
    case failure(error: String)
}

struct Point {
    var x: Double
    var y: Double

    func distance(to other: Point) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

extension Greeter: Speakable {
    typealias Voice = String

    func speak() -> String {
        return greet()
    }
}

actor Counter {
    var count: Int = 0

    func increment() {
        count += 1
    }
}

typealias StringArray = [String]

func topLevelFunction(x: Int, y: Int) -> Int {
    return x + y
}

let globalConstant = 42

let numbers = [1, 2, 3]
let doubled = numbers.map { n in
    n * 2
}

for item in numbers {
    print(item)
}

if let value = Optional.some(42) {
    print(value)
}
