// Core AST analysis using SwiftSyntax.
// Walks the syntax tree to extract symbol definitions, occurrences, and relationships.

import SwiftSyntax
import SwiftParser

final class Analyzer: SyntaxVisitor {
    let source: String
    let packageName: String
    let relativePath: String
    let converter: SourceLocationConverter

    var occurrences: [SCIPOccurrence] = []
    var symbols: [SCIPSymbolInformation] = []
    var scopeStack = ScopeStack()
    var seenSymbols: Set<String> = []
    var globalLocalIndex: Int = 0

    init(source: String, packageName: String, relativePath: String, tree: SourceFileSyntax) {
        self.source = source
        self.packageName = packageName
        self.relativePath = relativePath
        self.converter = SourceLocationConverter(fileName: relativePath, tree: tree)
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Helpers

    /// Convert a syntax node's position to a 0-indexed SCIP range [startLine, startCol, endLine, endCol].
    func range(for node: some SyntaxProtocol) -> [Int32] {
        let start = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        let end = converter.location(for: node.endPositionBeforeTrailingTrivia)
        return [
            Int32(start.line - 1),
            Int32(start.column - 1),
            Int32(end.line - 1),
            Int32(end.column - 1),
        ]
    }

    /// Convert a token's position to a 0-indexed SCIP range.
    func range(for token: TokenSyntax) -> [Int32] {
        let start = converter.location(for: token.positionAfterSkippingLeadingTrivia)
        let end = converter.location(for: token.endPositionBeforeTrailingTrivia)
        return [
            Int32(start.line - 1),
            Int32(start.column - 1),
            Int32(end.line - 1),
            Int32(end.column - 1),
        ]
    }

    /// Extract documentation comments from leading trivia.
    func extractDocComment(from node: some SyntaxProtocol) -> [String] {
        var lines: [String] = []
        for piece in node.leadingTrivia {
            switch piece {
            case .docLineComment(let text):
                let stripped = text.hasPrefix("/// ") ? String(text.dropFirst(4)) :
                               text.hasPrefix("///") ? String(text.dropFirst(3)) : text
                lines.append(stripped)
            case .docBlockComment(let text):
                var inner = text
                if inner.hasPrefix("/**") { inner = String(inner.dropFirst(3)) }
                if inner.hasSuffix("*/") { inner = String(inner.dropLast(2)) }
                lines.append(inner.trimmingCharacters(in: .whitespaces))
            default:
                break
            }
        }
        return lines
    }

    /// Check if a declaration has a static or class modifier.
    func isStatic(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { modifier in
            modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
        }
    }

    /// Record a symbol definition.
    func recordDefinition(symbol: String, range: [Int32], kind: Int32, displayName: String, documentation: [String] = [], enclosingSymbol: String = "") {
        occurrences.append(SCIPOccurrence(
            range: range,
            symbol: symbol,
            symbolRoles: SymbolRole.definition
        ))

        if !seenSymbols.contains(symbol) {
            seenSymbols.insert(symbol)
            symbols.append(SCIPSymbolInformation(
                symbol: symbol,
                documentation: documentation,
                kind: kind,
                displayName: displayName,
                enclosingSymbol: enclosingSymbol
            ))
        }
    }

    /// Record a symbol reference (read access).
    func recordReference(symbol: String, range: [Int32], roles: Int32 = SymbolRole.readAccess) {
        occurrences.append(SCIPOccurrence(
            range: range,
            symbol: symbol,
            symbolRoles: roles
        ))
    }

    // MARK: - Type Declarations

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let owner = scopeStack.qualifiedTypeName()
        let symbol = SCIPSymbolBuilder.classSymbol(package: packageName, owner: owner, name: name)
        let docs = extractDocComment(from: node)
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""

        recordDefinition(
            symbol: symbol,
            range: range(for: node.name),
            kind: SymbolKind.class,
            displayName: name,
            documentation: docs,
            enclosingSymbol: enclosing
        )

        if let inheritanceClause = node.inheritanceClause {
            recordInheritance(inheritanceClause, enclosingSymbol: symbol)
        }

        if let generics = node.genericParameterClause {
            recordGenericParameters(generics, owner: owner.isEmpty ? name : "\(owner).\(name)", ownerSymbol: symbol)
        }

        scopeStack.push(Scope(kind: .class, name: owner.isEmpty ? name : "\(owner).\(name)", symbol: symbol))
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        scopeStack.pop()
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let owner = scopeStack.qualifiedTypeName()
        let symbol = SCIPSymbolBuilder.structSymbol(package: packageName, owner: owner, name: name)
        let docs = extractDocComment(from: node)
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""

        recordDefinition(
            symbol: symbol,
            range: range(for: node.name),
            kind: SymbolKind.struct,
            displayName: name,
            documentation: docs,
            enclosingSymbol: enclosing
        )

        if let inheritanceClause = node.inheritanceClause {
            recordInheritance(inheritanceClause, enclosingSymbol: symbol)
        }

        if let generics = node.genericParameterClause {
            recordGenericParameters(generics, owner: owner.isEmpty ? name : "\(owner).\(name)", ownerSymbol: symbol)
        }

        scopeStack.push(Scope(kind: .struct, name: owner.isEmpty ? name : "\(owner).\(name)", symbol: symbol))
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        scopeStack.pop()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let owner = scopeStack.qualifiedTypeName()
        let symbol = SCIPSymbolBuilder.enumSymbol(package: packageName, owner: owner, name: name)
        let docs = extractDocComment(from: node)
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""

        recordDefinition(
            symbol: symbol,
            range: range(for: node.name),
            kind: SymbolKind.enum,
            displayName: name,
            documentation: docs,
            enclosingSymbol: enclosing
        )

        if let inheritanceClause = node.inheritanceClause {
            recordInheritance(inheritanceClause, enclosingSymbol: symbol)
        }

        if let generics = node.genericParameterClause {
            recordGenericParameters(generics, owner: owner.isEmpty ? name : "\(owner).\(name)", ownerSymbol: symbol)
        }

        scopeStack.push(Scope(kind: .enum, name: owner.isEmpty ? name : "\(owner).\(name)", symbol: symbol))
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        scopeStack.pop()
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let owner = scopeStack.qualifiedTypeName()
        let symbol = SCIPSymbolBuilder.protocolSymbol(package: packageName, owner: owner, name: name)
        let docs = extractDocComment(from: node)
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""

        recordDefinition(
            symbol: symbol,
            range: range(for: node.name),
            kind: SymbolKind.interface,
            displayName: name,
            documentation: docs,
            enclosingSymbol: enclosing
        )

        if let inheritanceClause = node.inheritanceClause {
            recordInheritance(inheritanceClause, enclosingSymbol: symbol)
        }

        scopeStack.push(Scope(kind: .protocol, name: owner.isEmpty ? name : "\(owner).\(name)", symbol: symbol))
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        scopeStack.pop()
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let owner = scopeStack.qualifiedTypeName()
        let symbol = SCIPSymbolBuilder.actorSymbol(package: packageName, owner: owner, name: name)
        let docs = extractDocComment(from: node)
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""

        recordDefinition(
            symbol: symbol,
            range: range(for: node.name),
            kind: SymbolKind.class,
            displayName: name,
            documentation: docs,
            enclosingSymbol: enclosing
        )

        if let inheritanceClause = node.inheritanceClause {
            recordInheritance(inheritanceClause, enclosingSymbol: symbol)
        }

        if let generics = node.genericParameterClause {
            recordGenericParameters(generics, owner: owner.isEmpty ? name : "\(owner).\(name)", ownerSymbol: symbol)
        }

        scopeStack.push(Scope(kind: .actor, name: owner.isEmpty ? name : "\(owner).\(name)", symbol: symbol))
        return .visitChildren
    }

    override func visitPost(_ node: ActorDeclSyntax) {
        scopeStack.pop()
    }

    // MARK: - Extensions

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let extendedType = node.extendedType.trimmedDescription
        let symbol = SCIPSymbolBuilder.classSymbol(package: packageName, name: extendedType)

        recordReference(symbol: symbol, range: range(for: node.extendedType))

        if let inheritanceClause = node.inheritanceClause {
            recordInheritance(inheritanceClause, enclosingSymbol: symbol)
        }

        scopeStack.push(Scope(kind: .extension, name: extendedType, symbol: symbol))
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        scopeStack.pop()
    }

    // MARK: - Functions and Methods

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let docs = extractDocComment(from: node)
        let owner = scopeStack.qualifiedTypeName()
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""
        let arity = node.signature.parameterClause.parameters.count
        let staticPrefix = isStatic(node.modifiers) ? "static." : ""

        let symbol: String
        let kind: Int32
        let displayName: String
        if owner.isEmpty {
            symbol = SCIPSymbolBuilder.functionSymbol(package: packageName, name: name, arity: arity)
            kind = SymbolKind.function
            displayName = name
        } else {
            symbol = SCIPSymbolBuilder.methodSymbol(package: packageName, owner: owner, name: "\(staticPrefix)\(name)", arity: arity)
            kind = SymbolKind.method
            displayName = isStatic(node.modifiers) ? "static \(name)" : name
        }

        recordDefinition(
            symbol: symbol,
            range: range(for: node.name),
            kind: kind,
            displayName: displayName,
            documentation: docs,
            enclosingSymbol: enclosing
        )

        if let generics = node.genericParameterClause {
            let paramOwner = owner.isEmpty ? name : "\(owner).\(name)"
            recordGenericParameters(generics, owner: paramOwner, ownerSymbol: symbol)
        }

        scopeStack.push(Scope(kind: .function, name: name, symbol: symbol))

        for param in node.signature.parameterClause.parameters {
            recordParameter(param, functionSymbol: symbol)
        }

        return .visitChildren
    }

    override func visitPost(_ node: FunctionDeclSyntax) {
        scopeStack.pop()
    }

    // MARK: - Initializers

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let owner = scopeStack.qualifiedTypeName()
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""
        let arity = node.signature.parameterClause.parameters.count
        let name = "init"

        let symbol = SCIPSymbolBuilder.methodSymbol(package: packageName, owner: owner, name: name, arity: arity)
        let docs = extractDocComment(from: node)

        recordDefinition(
            symbol: symbol,
            range: range(for: node.initKeyword),
            kind: SymbolKind.method,
            displayName: name,
            documentation: docs,
            enclosingSymbol: enclosing
        )

        scopeStack.push(Scope(kind: .function, name: name, symbol: symbol))

        for param in node.signature.parameterClause.parameters {
            recordParameter(param, functionSymbol: symbol)
        }

        return .visitChildren
    }

    override func visitPost(_ node: InitializerDeclSyntax) {
        scopeStack.pop()
    }

    // MARK: - Deinitializers

    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let owner = scopeStack.qualifiedTypeName()
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""
        let name = "deinit"

        let symbol = SCIPSymbolBuilder.methodSymbol(package: packageName, owner: owner, name: name, arity: 0)

        recordDefinition(
            symbol: symbol,
            range: range(for: node.deinitKeyword),
            kind: SymbolKind.method,
            displayName: name,
            enclosingSymbol: enclosing
        )

        scopeStack.push(Scope(kind: .function, name: name, symbol: symbol))
        return .visitChildren
    }

    override func visitPost(_ node: DeinitializerDeclSyntax) {
        scopeStack.pop()
    }

    // MARK: - Subscripts

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        let owner = scopeStack.qualifiedTypeName()
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""
        let arity = node.parameterClause.parameters.count
        let name = "subscript"

        let symbol = SCIPSymbolBuilder.methodSymbol(package: packageName, owner: owner, name: name, arity: arity)
        let docs = extractDocComment(from: node)

        recordDefinition(
            symbol: symbol,
            range: range(for: node.subscriptKeyword),
            kind: SymbolKind.method,
            displayName: name,
            documentation: docs,
            enclosingSymbol: enclosing
        )

        scopeStack.push(Scope(kind: .function, name: name, symbol: symbol))

        for param in node.parameterClause.parameters {
            recordParameter(param, functionSymbol: symbol)
        }

        return .visitChildren
    }

    override func visitPost(_ node: SubscriptDeclSyntax) {
        scopeStack.pop()
    }

    // MARK: - Properties and Variables

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let docs = extractDocComment(from: node)
        let owner = scopeStack.qualifiedTypeName()
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""
        let isInsideType = !owner.isEmpty
        let isInsideFunction = scopeStack.current.map { scope in
            scope.kind == .function || scope.kind == .closure
        } ?? false
        let staticPrefix = isStatic(node.modifiers) ? "static." : ""

        for binding in node.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
            let name = pattern.identifier.text

            if !isInsideFunction {
                let symbol: String
                let kind: Int32
                let displayName: String
                if isInsideType {
                    symbol = SCIPSymbolBuilder.propertySymbol(package: packageName, owner: owner, name: "\(staticPrefix)\(name)")
                    kind = SymbolKind.property
                    displayName = isStatic(node.modifiers) ? "static \(name)" : name
                } else {
                    symbol = SCIPSymbolBuilder.functionSymbol(package: packageName, name: name, arity: 0)
                    kind = SymbolKind.variable
                    displayName = name
                }

                recordDefinition(
                    symbol: symbol,
                    range: range(for: pattern.identifier),
                    kind: kind,
                    displayName: displayName,
                    documentation: docs,
                    enclosingSymbol: enclosing
                )
            } else {
                let idx = globalLocalIndex
                globalLocalIndex += 1
                let symbol = SCIPSymbolBuilder.localSymbol(index: idx)

                recordDefinition(
                    symbol: symbol,
                    range: range(for: pattern.identifier),
                    kind: SymbolKind.variable,
                    displayName: name
                )

                scopeStack.defineLocal(name: name, symbol: symbol)
            }
        }

        return .visitChildren
    }

    // MARK: - Enum Cases

    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        let owner = scopeStack.qualifiedTypeName()
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""
        let docs = extractDocComment(from: node)

        for element in node.elements {
            let name = element.name.text
            let symbol = SCIPSymbolBuilder.enumMemberSymbol(package: packageName, owner: owner, name: name)

            recordDefinition(
                symbol: symbol,
                range: range(for: element.name),
                kind: SymbolKind.enumMember,
                displayName: name,
                documentation: docs,
                enclosingSymbol: enclosing
            )

            if let paramClause = element.parameterClause {
                for param in paramClause.parameters {
                    if let firstName = param.firstName {
                        let paramName = firstName.text
                        if paramName != "_" {
                            let paramIdx = globalLocalIndex
                            globalLocalIndex += 1
                            let paramSymbol = SCIPSymbolBuilder.localSymbol(index: paramIdx)

                            recordDefinition(
                                symbol: paramSymbol,
                                range: range(for: firstName),
                                kind: SymbolKind.parameter,
                                displayName: paramName,
                                enclosingSymbol: symbol
                            )
                        }
                    }
                }
            }
        }

        return .visitChildren
    }

    // MARK: - Type Aliases

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let owner = scopeStack.qualifiedTypeName()
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""
        let docs = extractDocComment(from: node)

        let symbol = SCIPSymbolBuilder.typeAliasSymbol(package: packageName, owner: owner, name: name)

        recordDefinition(
            symbol: symbol,
            range: range(for: node.name),
            kind: SymbolKind.typeAlias,
            displayName: name,
            documentation: docs,
            enclosingSymbol: enclosing
        )

        return .visitChildren
    }

    // MARK: - Associated Types (in protocols)

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let owner = scopeStack.qualifiedTypeName()
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""
        let docs = extractDocComment(from: node)

        let symbol = SCIPSymbolBuilder.typeParameterSymbol(package: packageName, owner: owner, name: name)

        recordDefinition(
            symbol: symbol,
            range: range(for: node.name),
            kind: SymbolKind.typeParameter,
            displayName: name,
            documentation: docs,
            enclosingSymbol: enclosing
        )

        return .visitChildren
    }

    // MARK: - Imports

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let moduleName = node.path.map(\.name.text).joined(separator: ".")
        let symbol = SCIPSymbolBuilder.importSymbol(moduleName: moduleName)

        occurrences.append(SCIPOccurrence(
            range: range(for: node.path),
            symbol: symbol,
            symbolRoles: SymbolRole.import
        ))

        return .visitChildren
    }

    // MARK: - Operator Declarations (P2)

    override func visit(_ node: OperatorDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let docs = extractDocComment(from: node)
        let symbol = SCIPSymbolBuilder.functionSymbol(package: packageName, name: name, arity: 0)

        recordDefinition(
            symbol: symbol,
            range: range(for: node.name),
            kind: SymbolKind.function,
            displayName: name,
            documentation: docs
        )

        return .visitChildren
    }

    // MARK: - Precedence Groups (P2)

    override func visit(_ node: PrecedenceGroupDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let docs = extractDocComment(from: node)
        let symbol = SCIPSymbolBuilder.functionSymbol(package: packageName, name: name, arity: 0)

        recordDefinition(
            symbol: symbol,
            range: range(for: node.name),
            kind: SymbolKind.type,
            displayName: name,
            documentation: docs
        )

        return .visitChildren
    }

    // MARK: - Macro Declarations (P2, Swift 5.9+)

    override func visit(_ node: MacroDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let docs = extractDocComment(from: node)
        let owner = scopeStack.qualifiedTypeName()
        let enclosing = scopeStack.enclosingTypeSymbol() ?? ""

        let symbol: String
        if owner.isEmpty {
            symbol = SCIPSymbolBuilder.functionSymbol(package: packageName, name: name, arity: 0)
        } else {
            symbol = SCIPSymbolBuilder.methodSymbol(package: packageName, owner: owner, name: name, arity: 0)
        }

        recordDefinition(
            symbol: symbol,
            range: range(for: node.name),
            kind: SymbolKind.function,
            displayName: name,
            documentation: docs,
            enclosingSymbol: enclosing
        )

        return .visitChildren
    }

    // MARK: - Closures

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        let idx = globalLocalIndex
        globalLocalIndex += 1
        let symbol = SCIPSymbolBuilder.localSymbol(index: idx)

        scopeStack.push(Scope(kind: .closure, name: "<closure>", symbol: symbol))

        if let signature = node.signature {
            if let paramClause = signature.parameterClause {
                switch paramClause {
                case .simpleInput(let params):
                    for param in params {
                        let paramName = param.name.text
                        let paramIdx = globalLocalIndex
                        globalLocalIndex += 1
                        let paramSymbol = SCIPSymbolBuilder.localSymbol(index: paramIdx)

                        recordDefinition(
                            symbol: paramSymbol,
                            range: range(for: param.name),
                            kind: SymbolKind.parameter,
                            displayName: paramName
                        )
                        scopeStack.defineLocal(name: paramName, symbol: paramSymbol)
                    }
                case .parameterClause(let clause):
                    for param in clause.parameters {
                        let paramName = param.secondName?.text ?? param.firstName.text
                        let paramIdx = globalLocalIndex
                        globalLocalIndex += 1
                        let paramSymbol = SCIPSymbolBuilder.localSymbol(index: paramIdx)

                        recordDefinition(
                            symbol: paramSymbol,
                            range: range(for: param.secondName ?? param.firstName),
                            kind: SymbolKind.parameter,
                            displayName: paramName
                        )
                        scopeStack.defineLocal(name: paramName, symbol: paramSymbol)
                    }
                }
            }
        }

        return .visitChildren
    }

    override func visitPost(_ node: ClosureExprSyntax) {
        scopeStack.pop()
    }

    // MARK: - References

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.baseName.text

        if let localSymbol = scopeStack.lookupLocal(name: name) {
            recordReference(symbol: localSymbol, range: range(for: node.baseName))
        }
        return .visitChildren
    }

    // MARK: - Pattern Bindings (if let, guard let, etc.)

    override func visit(_ node: OptionalBindingConditionSyntax) -> SyntaxVisitorContinueKind {
        if let pattern = node.pattern.as(IdentifierPatternSyntax.self) {
            let name = pattern.identifier.text
            let idx = globalLocalIndex
            globalLocalIndex += 1
            let symbol = SCIPSymbolBuilder.localSymbol(index: idx)

            recordDefinition(
                symbol: symbol,
                range: range(for: pattern.identifier),
                kind: SymbolKind.variable,
                displayName: name
            )

            scopeStack.defineLocal(name: name, symbol: symbol)
        }
        return .visitChildren
    }

    // MARK: - For-in loops

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        if let pattern = node.pattern.as(IdentifierPatternSyntax.self) {
            let name = pattern.identifier.text
            let idx = globalLocalIndex
            globalLocalIndex += 1
            let symbol = SCIPSymbolBuilder.localSymbol(index: idx)

            recordDefinition(
                symbol: symbol,
                range: range(for: pattern.identifier),
                kind: SymbolKind.variable,
                displayName: name
            )

            scopeStack.defineLocal(name: name, symbol: symbol)
        }
        return .visitChildren
    }

    // MARK: - Switch Case Value Bindings (P2)

    override func visit(_ node: ValueBindingPatternSyntax) -> SyntaxVisitorContinueKind {
        if let idPattern = node.pattern.as(IdentifierPatternSyntax.self) {
            let name = idPattern.identifier.text
            let idx = globalLocalIndex
            globalLocalIndex += 1
            let symbol = SCIPSymbolBuilder.localSymbol(index: idx)

            recordDefinition(
                symbol: symbol,
                range: range(for: idPattern.identifier),
                kind: SymbolKind.variable,
                displayName: name
            )

            scopeStack.defineLocal(name: name, symbol: symbol)
        }
        return .visitChildren
    }

    // MARK: - Helpers for Inheritance and Generics

    private func recordInheritance(_ clause: InheritanceClauseSyntax, enclosingSymbol: String) {
        for inherited in clause.inheritedTypes {
            let typeName = inherited.type.trimmedDescription
            let typeSymbol = SCIPSymbolBuilder.classSymbol(package: packageName, name: typeName)
            recordReference(symbol: typeSymbol, range: range(for: inherited.type))
        }
    }

    private func recordGenericParameters(_ clause: GenericParameterClauseSyntax, owner: String, ownerSymbol: String) {
        for param in clause.parameters {
            let name = param.name.text
            let symbol = SCIPSymbolBuilder.typeParameterSymbol(package: packageName, owner: owner, name: name)

            recordDefinition(
                symbol: symbol,
                range: range(for: param.name),
                kind: SymbolKind.typeParameter,
                displayName: name,
                enclosingSymbol: ownerSymbol
            )
        }
    }

    private func recordParameter(_ param: FunctionParameterSyntax, functionSymbol: String) {
        let nameToken = param.secondName ?? param.firstName
        let name = nameToken.text
        guard name != "_" else { return }

        let idx = globalLocalIndex
        globalLocalIndex += 1
        let symbol = SCIPSymbolBuilder.localSymbol(index: idx)

        recordDefinition(
            symbol: symbol,
            range: range(for: nameToken),
            kind: SymbolKind.parameter,
            displayName: name,
            enclosingSymbol: functionSymbol
        )

        scopeStack.defineLocal(name: name, symbol: symbol)
    }

    // MARK: - Build Document

    func buildDocument() -> SCIPDocument {
        SCIPDocument(
            language: "swift",
            relativePath: relativePath,
            occurrences: occurrences,
            symbols: symbols
        )
    }
}

// MARK: - Public Entry Point

public func analyzeFile(source: String, packageName: String, relativePath: String) -> SCIPDocument {
    let tree = Parser.parse(source: source)
    let analyzer = Analyzer(
        source: source,
        packageName: packageName,
        relativePath: relativePath,
        tree: tree
    )
    analyzer.walk(tree)
    return analyzer.buildDocument()
}
