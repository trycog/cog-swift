// SCIP data structures matching the SCIP protobuf schema.
// See: https://github.com/sourcegraph/scip/blob/main/scip.proto

struct SCIPIndex {
    var metadata: SCIPMetadata
    var documents: [SCIPDocument]
    var externalSymbols: [SCIPSymbolInformation]
}

struct SCIPMetadata {
    var version: Int32 = 0 // UnspecifiedProtocolVersion
    var toolInfo: SCIPToolInfo
    var projectRoot: String
    var textDocumentEncoding: Int32 = 1 // UTF8
}

struct SCIPToolInfo {
    var name: String
    var version: String
    var arguments: [String]
}

struct SCIPDocument {
    var language: String
    var relativePath: String
    var occurrences: [SCIPOccurrence]
    var symbols: [SCIPSymbolInformation]
}

struct SCIPOccurrence {
    var range: [Int32]
    var symbol: String
    var symbolRoles: Int32
    var syntaxKind: Int32 = 0
    var enclosingRange: [Int32] = []
}

struct SCIPSymbolInformation {
    var symbol: String
    var documentation: [String] = []
    var relationships: [SCIPRelationship] = []
    var kind: Int32 = 0
    var displayName: String = ""
    var enclosingSymbol: String = ""
}

struct SCIPRelationship {
    var symbol: String
    var isReference: Bool = false
    var isImplementation: Bool = false
    var isTypeDefinition: Bool = false
    var isDefinition: Bool = false
}

// Symbol roles (bit flags)
enum SymbolRole {
    static let definition: Int32 = 0x1
    static let `import`: Int32 = 0x2
    static let writeAccess: Int32 = 0x4
    static let readAccess: Int32 = 0x8
}

// Symbol kinds
enum SymbolKind {
    static let `class`: Int32 = 7
    static let constant: Int32 = 8
    static let `enum`: Int32 = 11
    static let enumMember: Int32 = 12
    static let field: Int32 = 15
    static let function: Int32 = 17
    static let interface: Int32 = 21
    static let method: Int32 = 26
    static let module: Int32 = 29
    static let parameter: Int32 = 37
    static let property: Int32 = 41
    static let `struct`: Int32 = 49
    static let type: Int32 = 54
    static let typeAlias: Int32 = 55
    static let typeParameter: Int32 = 58
    static let variable: Int32 = 61
}
