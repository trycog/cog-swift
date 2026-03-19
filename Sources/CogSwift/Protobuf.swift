// Hand-rolled protobuf encoder for SCIP output.
// Supports only the wire types and field types needed by SCIP.

import Foundation

enum WireType {
    static let varint: UInt8 = 0
    static let delimited: UInt8 = 2
}

enum ProtobufEncoder {

    // MARK: - Low-level primitives

    static func encodeVarint(_ value: UInt64) -> Data {
        var data = Data()
        var v = value
        while v > 0x7F {
            data.append(UInt8(v & 0x7F) | 0x80)
            v >>= 7
        }
        data.append(UInt8(v))
        return data
    }

    static func encodeSignedVarint(_ value: Int64) -> Data {
        encodeVarint(UInt64(bitPattern: value))
    }

    static func encodeTag(fieldNumber: Int, wireType: UInt8) -> Data {
        encodeVarint(UInt64(fieldNumber << 3 | Int(wireType)))
    }

    // MARK: - Field encoders

    static func encodeStringField(fieldNumber: Int, value: String) -> Data {
        guard !value.isEmpty else { return Data() }
        let bytes = Data(value.utf8)
        var data = encodeTag(fieldNumber: fieldNumber, wireType: WireType.delimited)
        data.append(encodeVarint(UInt64(bytes.count)))
        data.append(bytes)
        return data
    }

    static func encodeInt32Field(fieldNumber: Int, value: Int32) -> Data {
        guard value != 0 else { return Data() }
        var data = encodeTag(fieldNumber: fieldNumber, wireType: WireType.varint)
        data.append(encodeVarint(UInt64(bitPattern: Int64(value))))
        return data
    }

    static func encodeBoolField(fieldNumber: Int, value: Bool) -> Data {
        guard value else { return Data() }
        var data = encodeTag(fieldNumber: fieldNumber, wireType: WireType.varint)
        data.append(encodeVarint(1))
        return data
    }

    static func encodeMessageField(fieldNumber: Int, data messageData: Data) -> Data {
        guard !messageData.isEmpty else { return Data() }
        var data = encodeTag(fieldNumber: fieldNumber, wireType: WireType.delimited)
        data.append(encodeVarint(UInt64(messageData.count)))
        data.append(messageData)
        return data
    }

    static func encodePackedInt32Field(fieldNumber: Int, values: [Int32]) -> Data {
        guard !values.isEmpty else { return Data() }
        var packed = Data()
        for v in values {
            packed.append(encodeVarint(UInt64(bitPattern: Int64(v))))
        }
        var data = encodeTag(fieldNumber: fieldNumber, wireType: WireType.delimited)
        data.append(encodeVarint(UInt64(packed.count)))
        data.append(packed)
        return data
    }

    static func encodeRepeatedStringField(fieldNumber: Int, values: [String]) -> Data {
        var data = Data()
        for v in values {
            data.append(encodeStringField(fieldNumber: fieldNumber, value: v))
        }
        return data
    }

    // MARK: - SCIP message encoders

    static func encode(index: SCIPIndex) -> Data {
        var data = Data()
        data.append(encodeMessageField(fieldNumber: 1, data: encode(metadata: index.metadata)))
        for doc in index.documents {
            data.append(encodeMessageField(fieldNumber: 2, data: encode(document: doc)))
        }
        for sym in index.externalSymbols {
            data.append(encodeMessageField(fieldNumber: 3, data: encode(symbolInformation: sym)))
        }
        return data
    }

    static func encode(metadata: SCIPMetadata) -> Data {
        var data = Data()
        data.append(encodeInt32Field(fieldNumber: 1, value: metadata.version))
        data.append(encodeMessageField(fieldNumber: 2, data: encode(toolInfo: metadata.toolInfo)))
        data.append(encodeStringField(fieldNumber: 3, value: metadata.projectRoot))
        data.append(encodeInt32Field(fieldNumber: 4, value: metadata.textDocumentEncoding))
        return data
    }

    static func encode(toolInfo: SCIPToolInfo) -> Data {
        var data = Data()
        data.append(encodeStringField(fieldNumber: 1, value: toolInfo.name))
        data.append(encodeStringField(fieldNumber: 2, value: toolInfo.version))
        data.append(encodeRepeatedStringField(fieldNumber: 3, values: toolInfo.arguments))
        return data
    }

    static func encode(document: SCIPDocument) -> Data {
        var data = Data()
        data.append(encodeStringField(fieldNumber: 4, value: document.language))
        data.append(encodeStringField(fieldNumber: 1, value: document.relativePath))
        for occ in document.occurrences {
            data.append(encodeMessageField(fieldNumber: 2, data: encode(occurrence: occ)))
        }
        for sym in document.symbols {
            data.append(encodeMessageField(fieldNumber: 3, data: encode(symbolInformation: sym)))
        }
        return data
    }

    static func encode(occurrence: SCIPOccurrence) -> Data {
        var data = Data()
        data.append(encodePackedInt32Field(fieldNumber: 1, values: occurrence.range))
        data.append(encodeStringField(fieldNumber: 2, value: occurrence.symbol))
        data.append(encodeInt32Field(fieldNumber: 3, value: occurrence.symbolRoles))
        data.append(encodeInt32Field(fieldNumber: 5, value: occurrence.syntaxKind))
        data.append(encodePackedInt32Field(fieldNumber: 7, values: occurrence.enclosingRange))
        return data
    }

    static func encode(symbolInformation: SCIPSymbolInformation) -> Data {
        var data = Data()
        data.append(encodeStringField(fieldNumber: 1, value: symbolInformation.symbol))
        data.append(encodeRepeatedStringField(fieldNumber: 3, values: symbolInformation.documentation))
        for rel in symbolInformation.relationships {
            data.append(encodeMessageField(fieldNumber: 4, data: encode(relationship: rel)))
        }
        data.append(encodeInt32Field(fieldNumber: 5, value: symbolInformation.kind))
        data.append(encodeStringField(fieldNumber: 6, value: symbolInformation.displayName))
        data.append(encodeStringField(fieldNumber: 7, value: symbolInformation.enclosingSymbol))
        return data
    }

    static func encode(relationship: SCIPRelationship) -> Data {
        var data = Data()
        data.append(encodeStringField(fieldNumber: 1, value: relationship.symbol))
        data.append(encodeBoolField(fieldNumber: 2, value: relationship.isReference))
        data.append(encodeBoolField(fieldNumber: 3, value: relationship.isImplementation))
        data.append(encodeBoolField(fieldNumber: 4, value: relationship.isTypeDefinition))
        data.append(encodeBoolField(fieldNumber: 5, value: relationship.isDefinition))
        return data
    }
}
