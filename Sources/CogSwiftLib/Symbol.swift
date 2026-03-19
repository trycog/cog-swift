// SCIP symbol string builder.
// Format: scheme " " manager " " package " " version " " descriptor...

public enum SCIPSymbolBuilder {

    public static func escape(_ name: String) -> String {
        let isSimple = name.allSatisfy { c in
            c.isLetter || c.isNumber || c == "_" || c == "-" || c == "$" || c == "+"
        }
        if isSimple && !name.isEmpty {
            return name
        }
        let escaped = name.replacingOccurrences(of: "`", with: "``")
        return "`\(escaped)`"
    }

    public static func prefix(package: String) -> String {
        "file . \(escape(package)) unversioned "
    }

    /// Convert a dot-separated owner path into chained # descriptors.
    /// e.g. "Outer.Inner" -> "Outer#Inner#"
    public static func ownerDescriptor(_ owner: String) -> String {
        guard !owner.isEmpty else { return "" }
        return owner.split(separator: ".").map { escape(String($0)) + "#" }.joined()
    }

    public static func moduleSymbol(package: String, name: String) -> String {
        "\(prefix(package: package))\(escape(name))/"
    }

    public static func classSymbol(package: String, owner: String = "", name: String) -> String {
        "\(prefix(package: package))\(ownerDescriptor(owner))\(escape(name))#"
    }

    public static func structSymbol(package: String, owner: String = "", name: String) -> String {
        classSymbol(package: package, owner: owner, name: name)
    }

    public static func enumSymbol(package: String, owner: String = "", name: String) -> String {
        classSymbol(package: package, owner: owner, name: name)
    }

    public static func protocolSymbol(package: String, owner: String = "", name: String) -> String {
        classSymbol(package: package, owner: owner, name: name)
    }

    public static func actorSymbol(package: String, owner: String = "", name: String) -> String {
        classSymbol(package: package, owner: owner, name: name)
    }

    public static func methodSymbol(package: String, owner: String, name: String, arity: Int) -> String {
        "\(prefix(package: package))\(ownerDescriptor(owner))\(escape(name))(\(arity))."
    }

    public static func functionSymbol(package: String, name: String, arity: Int) -> String {
        "\(prefix(package: package))\(escape(name))(\(arity))."
    }

    public static func propertySymbol(package: String, owner: String, name: String) -> String {
        "\(prefix(package: package))\(ownerDescriptor(owner))\(escape(name))."
    }

    public static func enumMemberSymbol(package: String, owner: String, name: String) -> String {
        "\(prefix(package: package))\(ownerDescriptor(owner))\(escape(name))."
    }

    public static func typeAliasSymbol(package: String, owner: String = "", name: String) -> String {
        "\(prefix(package: package))\(ownerDescriptor(owner))\(escape(name))#"
    }

    public static func typeParameterSymbol(package: String, owner: String, name: String) -> String {
        "\(prefix(package: package))\(ownerDescriptor(owner))[\(escape(name))]"
    }

    public static func localSymbol(index: Int) -> String {
        "local \(index)"
    }

    public static func importSymbol(moduleName: String) -> String {
        "file . \(escape(moduleName)) unversioned "
    }
}
