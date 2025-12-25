//
//  DeeplinkResolvedModel.swift
//  PaylisherExample
//
//  Created by Paylisher SDK on 24.12.2025.
//

import Foundation

// MARK: - Mongo Wrappers
struct MongoOID: Codable {
    let oid: String

    enum CodingKeys: String, CodingKey {
        case oid = "$oid"
    }
}

struct MongoDate: Codable {
    let date: String

    enum CodingKeys: String, CodingKey {
        case date = "$date"
    }
}

// MARK: - JSONValue for Dynamic MetaData
/// MetaData içinde number/string/bool/object karışık geleceği için generic JSON value type
enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
            return
        }

        if let number = try? container.decode(Double.self) {
            self = .number(number)
            return
        }

        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }

        if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
            return
        }

        if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported JSON value type"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    /// Paylisher properties için Any'a dönüştür
    func toAny() -> Any {
        switch self {
        case .string(let s):
            return s
        case .number(let n):
            return n
        case .bool(let b):
            return b
        case .object(let o):
            return o.mapValues { $0.toAny() }
        case .array(let a):
            return a.map { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
}

// MARK: - Resolved DeepLink Payload
/// Backend'den gelen campaign/deeplink bilgilerinin tam modeli
struct ResolvedDeepLinkPayload: Codable {
    let id: MongoOID?
    let teamId: String?
    let projectId: String?
    let sourceId: String?
    let type: String?
    let title: String?
    let keyName: String?
    let webUrl: String?
    let iosUrl: String?
    let androidUrl: String?
    let fallbackUrl: String?
    let scheme: String?
    let webhookUrl: String?
    let createdAt: MongoDate?
    let updatedAt: MongoDate?
    let v: Int?
    let adId: MongoOID?
    let metaData: [String: JSONValue]?
    let jid: String? // ✅ Journey ID (campaign tracking için)

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case teamId, projectId, sourceId, type, title, keyName
        case webUrl, iosUrl, androidUrl, fallbackUrl, scheme, webhookUrl
        case createdAt, updatedAt
        case v = "__v"
        case adId
        case metaData
        case jid // ✅ Journey ID
    }

    /// Paylisher'a gönderilecek properties dictionary'sini oluşturur
    func toPropertiesDictionary() -> [String: Any] {
        var props: [String: Any] = [:]

        // Tüm alanları ekle
        props["_id"] = id?.oid ?? ""
        props["teamId"] = teamId ?? ""
        props["projectId"] = projectId ?? ""
        props["sourceId"] = sourceId ?? ""
        props["type"] = type ?? ""
        props["title"] = title ?? ""
        props["keyName"] = keyName ?? ""
        props["webUrl"] = webUrl ?? ""
        props["iosUrl"] = iosUrl ?? ""
        props["androidUrl"] = androidUrl ?? ""
        props["fallbackUrl"] = fallbackUrl ?? ""
        props["scheme"] = scheme ?? ""
        props["webhookUrl"] = webhookUrl ?? ""
        props["createdAt"] = createdAt?.date ?? ""
        props["updatedAt"] = updatedAt?.date ?? ""
        props["__v"] = v ?? 0
        props["adId"] = adId?.oid ?? ""

        // ✅ Journey ID ekle (varsa)
        if let jid = jid {
            props["jid"] = jid
        }

        // MetaData'yı düzleştirerek ekle (nested structure yerine flat)
        if let meta = metaData {
            let metaDict = meta.mapValues { $0.toAny() }
            props["metaData"] = metaDict

            // MetaData içindeki her key'i ayrıca root seviyeye de ekle (kolay filtreleme için)
            for (key, value) in metaDict {
                props["meta_\(key)"] = value
            }
        } else {
            props["metaData"] = [String: Any]()
        }

        return props
    }
}
