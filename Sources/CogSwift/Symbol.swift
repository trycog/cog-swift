// SCIP symbol string builder.
// Format: scheme " " manager " " package " " version " " descriptor...

enum SCIPSymbolBuilder {

    // MARK: - Escaping

    /// Escape an identifier for use in a SCIP symbol string.
    /// Simple identifiers (alphanumeric, _, -, $, +) are kept as-is.
    /// Complex names are wrapped in backticks with internal backticks doubled.
    static func escape(_ name: String) -> String {
        let isSimple = name.allSatisfy { c in
            c.isLetter || c.isNumber || c == "_" || c == "-" || c == "$" || c == "+"
        }
        if isSimple && !name.isEmpty {
            return name
        }
        let escaped = name.replacingOccurrences(of: "`", with: "``")
        return "`\(escaped)`"
    }

    // MARK: - Symbol prefix

    /// Build the common prefix: "file . <package> unversioned "
    static func prefix(package: String) -> String {
        "file . \(escape(package)) unversioned "
    }

    // MARK: - Symbol builders

    static func moduleSymbol(package: String, name: String) -> String {
        "\(prefix(package: package))\(escape(name))/"
    }

    static func classSymbol(package: String, owner: String = "", name: String) -> String {
        if owner.isEmpty {
            return "\(prefix(package: package))\(escape(name))#"
        }
        return "\(prefix(package: package))\(escape(owner))#\(escape(name))#"
    }

    static func structSymbol(package: String, owner: String = "", name: String) -> String {
        // Structs use the same # descriptor as classes in SCIP
        classSymbol(package: package, owner: owner, name: name)
    }

    static func enumSymbol(package: String, owner: String = "", name: String) -> String {
        classSymbol(package: package, owner: owner, name: name)
    }

    static func protocolSymbol(package: String, owner: String = "", name: String) -> String {
        classSymbol(package: package, owner: owner, name: name)
    }

    static func actorSymbol(package: String, owner: String = "", name: String) -> String {
        classSymbol(package: package, owner: owner, name: name)
    }

    static func methodSymbol(package: String, owner: String, name: String, arity: Int) -> String {
        "\(prefix(package: package))\(escape(owner))#\(escape(name))(\(arity))."
    }

    static func functionSymbol(package: String, name: String, arity: Int) -> String {
        "\(prefix(package: package))\(escape(name))(\(arity))."
    }

    static func propertySymbol(package: String, owner: String, name: String) -> String {
        "\(prefix(package: package))\(escape(owner))#\(escape(name))."
    }

    static func enumMemberSymbol(package: String, owner: String, name: String) -> String {
        "\(prefix(package: package))\(escape(owner))#\(escape(name))."
    }

    static func typeAliasSymbol(package: String, owner: String = "", name: String) -> String {
        if owner.isEmpty {
            return "\(prefix(package: package))\(escape(name))#"
        }
        return "\(prefix(package: package))\(escape(owner))#\(escape(name))#"
    }

    static func typeParameterSymbol(package: String, owner: String, name: String) -> String {
        "\(prefix(package: package))\(escape(owner))#[\(escape(name))]"
    }

    static func localSymbol(index: Int) -> String {
        "local \(index)"
    }

    static func importSymbol(moduleName: String) -> String {
        "file . \(escape(moduleName)) unversioned "
    }
}
