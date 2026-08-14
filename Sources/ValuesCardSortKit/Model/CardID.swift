// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Identifies a card in a session: either one of the 83 printed cards, or one
/// the sorter wrote themselves (R4, deviation D5).
///
/// The reference implementation uses `"c" + Date.now()` for custom cards
/// (`reference/valuescardsort.jsx`), which collides if two cards are written
/// inside the same millisecond and is not stable across devices. A `UUID` is
/// neither. This is a native-idiom departure from the reference with no
/// behavioral consequence — flagged here rather than made silently.
///
/// Encodes as a string (`"deck:42"`, `"custom:<uuid>"`) rather than as a
/// tagged object, so pile arrays stay legible in a persisted session and can
/// be read by a human debugging a store.
public enum CardID: Hashable, Sendable, Codable, CustomStringConvertible {
    case deck(Int)
    case custom(UUID)

    public var description: String {
        switch self {
        case .deck(let n): "deck:\(n)"
        case .custom(let id): "custom:\(id.uuidString)"
        }
    }

    /// True for the sorter's own cards — they are the only ones that carry
    /// their text in the session rather than in the deck file.
    public var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = CardID(raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Not a card id: \(raw)")
            )
        }
        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    init?(_ raw: String) {
        if let n = raw.dropPrefixIfPresent("deck:").flatMap(Int.init) {
            self = .deck(n)
        } else if let uuid = raw.dropPrefixIfPresent("custom:").flatMap(UUID.init(uuidString:)) {
            self = .custom(uuid)
        } else {
            return nil
        }
    }
}

extension String {
    fileprivate func dropPrefixIfPresent(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}

/// A card the sorter wrote themselves (R4).
///
/// The paper instrument ships three blank "Other Value:" cards; the app allows
/// any number (deviation D5, SPEC §2.1). These belong to the person rather than
/// to a session — SPEC §5.1 offers prior sessions' custom cards at the start of
/// a new one — which is why they carry their own text.
public struct CustomCard: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    /// Uppercased on creation, to sit alongside the printed cards (R4).
    public let name: String
    public let descriptor: String
    public let createdAt: Date

    /// Descriptor used when the sorter names a value but does not gloss it (R4).
    public static let defaultDescriptor = "a value I wrote myself"

    /// Returns `nil` if the name is blank — R4 requires a name.
    public init?(name: String, descriptor: String? = nil, id: UUID = UUID(), createdAt: Date = Date()) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedName.isEmpty else { return nil }
        let trimmedDescriptor = (descriptor ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        self.id = id
        self.name = trimmedName
        self.descriptor = trimmedDescriptor.isEmpty ? Self.defaultDescriptor : trimmedDescriptor
        self.createdAt = createdAt
    }

    public var cardID: CardID { .custom(id) }
}
