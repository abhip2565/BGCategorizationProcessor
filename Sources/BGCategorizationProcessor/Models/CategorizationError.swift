import Foundation

public enum CategorizationError: Error, Sendable {
    case embeddingUnavailable
    case embeddingFailed(text: String)
    case modelLoadFailed(reason: String)
    case databaseError(underlying: Error)
    case categoryNotFound(id: String)
    case textTooShort
    case resultDeserializationFailed
}
