// Scope stack management for tracking nested declarations during AST analysis.

enum ScopeKind {
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

struct Scope {
    var kind: ScopeKind
    var name: String
    var symbol: String
    var localVariables: [String: String] = [:]  // name -> SCIP symbol
    var localIndex: Int = 0
}

struct ScopeStack {
    private var stack: [Scope] = []

    var isEmpty: Bool { stack.isEmpty }
    var count: Int { stack.count }

    mutating func push(_ scope: Scope) {
        stack.append(scope)
    }

    @discardableResult
    mutating func pop() -> Scope? {
        stack.popLast()
    }

    var current: Scope? {
        stack.last
    }

    /// Walk up the stack to find the enclosing type name (class, struct, enum, protocol, actor, extension).
    func enclosingTypeName() -> String? {
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

    /// Walk up the stack to find the enclosing type's SCIP symbol.
    func enclosingTypeSymbol() -> String? {
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

    /// Get the fully qualified name by joining all type scope names with ".".
    func qualifiedTypeName() -> String {
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

    /// Define a local variable in the current scope.
    mutating func defineLocal(name: String, symbol: String) {
        guard !stack.isEmpty else { return }
        stack[stack.count - 1].localVariables[name] = symbol
    }

    /// Look up a local variable, searching from innermost scope outward.
    func lookupLocal(name: String) -> String? {
        for scope in stack.reversed() {
            if let symbol = scope.localVariables[name] {
                return symbol
            }
        }
        return nil
    }

    /// Get and increment the local variable index in the current scope.
    mutating func nextLocalIndex() -> Int {
        guard !stack.isEmpty else { return 0 }
        let index = stack[stack.count - 1].localIndex
        stack[stack.count - 1].localIndex = index + 1
        return index
    }
}
