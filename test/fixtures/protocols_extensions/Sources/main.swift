protocol Drawable {
    associatedtype Color
    func draw() -> String
    var canvas: String { get }
}

protocol Resizable {
    func resize(to scale: Double)
}

struct Circle: Drawable, Resizable {
    typealias Color = String

    var radius: Double
    var canvas: String = "default"

    func draw() -> String {
        return "Circle(\(radius))"
    }

    func resize(to scale: Double) {
        // resize
    }
}

extension Circle {
    var diameter: Double {
        return radius * 2
    }

    func area() -> Double {
        return 3.14159 * radius * radius
    }
}

extension Circle: CustomStringConvertible {
    var description: String {
        return "Circle(radius: \(radius))"
    }
}

/// An operator for combining shapes.
infix operator <>

/// Custom precedence group.
precedencegroup CombinePrecedence {
    higherThan: AdditionPrecedence
    associativity: left
}
