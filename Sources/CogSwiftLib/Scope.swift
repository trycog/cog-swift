// Scope stack management for tracking nested declarations during AST analysis.

public enum ScopeKind: Sendable {
    case topLevel
    case module
    case `class`
    case `struct`
    case `enum`
    case `protocol`
    case actor
    case `extension`
    case function
    case closure
}

public struct Scope: Sendable {
    public var kind: ScopeKind
    public var name: String
    public var symbol: String
    public var localVariables: [String: String] = [:]
    public var localIndex: Int = 0

    public init(kind: ScopeKind, name: String, symbol: String, localVariables: [String: String] = [:], localIndex: Int = 0) {
        self.kind = kind
        self.name = name
        self.symbol = symbol
        self.localVariables = localVariables
        self.localIndex = localIndex
    }
}

public struct ScopeStack: Sendable {
    private var stack: [Scope] = []

    public init() {}

    public var isEmpty: Bool { stack.isEmpty }
    public var count: Int { stack.count }

    public mutating func push(_ scope: Scope) {
        stack.append(scope)
    }

    @discardableResult
    public mutating func pop() -> Scope? {
        stack.popLast()
    }

    public var current: Scope? {
        stack.last
    }

    public func enclosingTypeName() -> String? {
        for scope in stack.reversed() {
            switch scope.kind {
            case .class, .struct, .enum, .protocol, .actor, .extension:
                return scope.name
            default:
                continue
            }
        }
        return nil
    }

    public func enclosingTypeSymbol() -> String? {
        for scope in stack.reversed() {
            switch scope.kind {
            case .class, .struct, .enum, .protocol, .actor, .extension:
                return scope.symbol
            default:
                continue
            }
        }
        return nil
    }

    public func qualifiedTypeName() -> String {
        stack
            .filter { scope in
                switch scope.kind {
                case .class, .struct, .enum, .protocol, .actor, .extension:
                    return true
                default:
                    return false
                }
            }
            .map(\.name)
            .joined(separator: ".")
    }

    public mutating func defineLocal(name: String, symbol: String) {
        guard !stack.isEmpty else { return }
        stack[stack.count - 1].localVariables[name] = symbol
    }

    public func lookupLocal(name: String) -> String? {
        for scope in stack.reversed() {
            if let symbol = scope.localVariables[name] {
                return symbol
            }
        }
        return nil
    }

    public mutating func nextLocalIndex() -> Int {
        guard !stack.isEmpty else { return 0 }
        let index = stack[stack.count - 1].localIndex
        stack[stack.count - 1].localIndex = index + 1
        return index
    }
}
