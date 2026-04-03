import Accelerate
import BGCategorizationProcessor
@preconcurrency import CoreML
import Foundation

public final class CoreMLEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    public let dimensions: Int = 384

    private let model: MLModel
    private let tokenizer: WordPieceTokenizer
    private let inputNames: [String]
    private let outputName: String

    public convenience init() throws {
        try self.init(bundle: .module)
    }

    public convenience init(
        bundle: Bundle,
        modelResource: String = "MiniLMEmbedding",
        vocabResource: String = "vocab",
        subdirectory: String? = "MiniLM"
    ) throws {
        guard let modelURL = bundle.url(
            forResource: modelResource,
            withExtension: "mlmodelc",
            subdirectory: subdirectory
        ) else {
            throw CategorizationError.modelLoadFailed(
                reason: "Missing bundled model resource \(modelResource).mlmodelc"
            )
        }

        guard let vocabURL = bundle.url(
            forResource: vocabResource,
            withExtension: "txt",
            subdirectory: subdirectory
        ) else {
            throw CategorizationError.modelLoadFailed(
                reason: "Missing bundled vocab resource \(vocabResource).txt"
            )
        }

        try self.init(modelURL: modelURL, vocabURL: vocabURL)
    }

    public init(modelURL: URL, vocabURL: URL) throws {
        do {
            self.model = try MLModel(contentsOf: modelURL)
            self.tokenizer = try WordPieceTokenizer(vocabURL: vocabURL)
        } catch {
            throw CategorizationError.modelLoadFailed(reason: error.localizedDescription)
        }

        let modelInputs = Set(model.modelDescription.inputDescriptionsByName.keys)
        let acceptedInputs = ["input_ids", "attention_mask", "token_type_ids"]
        self.inputNames = acceptedInputs.filter(modelInputs.contains)

        guard let outputName = model.modelDescription.outputDescriptionsByName.first(where: {
            $0.value.type == .multiArray
        })?.key else {
            throw CategorizationError.modelLoadFailed(reason: "Missing multi-array output")
        }

        self.outputName = outputName
    }

    public func embed(_ text: String) async throws -> [Float] {
        let encoded = tokenizer.encode(text, maxLength: 256)
        let inputIDs = try makeArray(from: encoded.ids)
        let attentionMask = try makeArray(from: encoded.attentionMask)
        let tokenTypeIDs = try makeArray(from: Array(repeating: 0, count: encoded.ids.count))

        var features: [String: MLFeatureValue] = [:]
        for name in inputNames {
            switch name {
            case "input_ids":
                features[name] = MLFeatureValue(multiArray: inputIDs)
            case "attention_mask":
                features[name] = MLFeatureValue(multiArray: attentionMask)
            case "token_type_ids":
                features[name] = MLFeatureValue(multiArray: tokenTypeIDs)
            default:
                break
            }
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: features)
        let output = try model.prediction(from: provider)

        guard let hiddenStates = output.featureValue(for: outputName)?.multiArrayValue else {
            throw CategorizationError.embeddingFailed(text: String(text.prefix(50)))
        }

        return normalize(meanPool(hiddenStates: hiddenStates, attentionMask: encoded.attentionMask))
    }

    private func makeArray(from values: [Int32]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [1, NSNumber(value: values.count)], dataType: .int32)
        for (index, value) in values.enumerated() {
            array[[0, NSNumber(value: index)]] = NSNumber(value: value)
        }
        return array
    }

    private func meanPool(hiddenStates: MLMultiArray, attentionMask: [Int32]) -> [Float] {
        let sequenceLength = attentionMask.count
        guard sequenceLength > 0 else {
            return Array(repeating: 0, count: dimensions)
        }

        let shape = hiddenStates.shape.map(\.intValue)
        let featureCount = shape.last ?? dimensions
        var pooled = Array(repeating: Float.zero, count: featureCount)
        var tokenCount = 0

        let strides = hiddenStates.strides.map(\.intValue)

        for tokenIndex in 0..<sequenceLength where attentionMask[tokenIndex] != 0 {
            tokenCount += 1
            for featureIndex in 0..<featureCount {
                let flatIndex: Int
                if shape.count == 3 {
                    flatIndex = tokenIndex * strides[1] + featureIndex * strides[2]
                } else if shape.count == 2 {
                    flatIndex = tokenIndex * strides[0] + featureIndex * strides[1]
                } else {
                    flatIndex = tokenIndex * featureCount + featureIndex
                }
                pooled[featureIndex] += value(in: hiddenStates, at: flatIndex)
            }
        }

        guard tokenCount > 0 else {
            return pooled
        }

        let divisor = Float(tokenCount)
        return pooled.map { $0 / divisor }
    }

    private func value(in array: MLMultiArray, at flatIndex: Int) -> Float {
        switch array.dataType {
        case .float16:
            let pointer = array.dataPointer.bindMemory(to: Float16.self, capacity: array.count)
            return Float(pointer[flatIndex])
        case .float32:
            let pointer = array.dataPointer.bindMemory(to: Float32.self, capacity: array.count)
            return pointer[flatIndex]
        case .double:
            let pointer = array.dataPointer.bindMemory(to: Double.self, capacity: array.count)
            return Float(pointer[flatIndex])
        case .int32:
            let pointer = array.dataPointer.bindMemory(to: Int32.self, capacity: array.count)
            return Float(pointer[flatIndex])
        case .int8:
            let pointer = array.dataPointer.bindMemory(to: Int8.self, capacity: array.count)
            return Float(pointer[flatIndex])
        @unknown default:
            return array[flatIndex].floatValue
        }
    }

    private func normalize(_ vector: [Float]) -> [Float] {
        guard !vector.isEmpty else {
            return vector
        }

        let magnitude = sqrt(vDSP.sum(vDSP.multiply(vector, vector)))
        guard magnitude > 0 else {
            return vector
        }

        return vector.map { $0 / magnitude }
    }
}

struct WordPieceTokenizer: Sendable {
    private let vocabulary: [String: Int32]
    private let unknownTokenID: Int32
    private let clsTokenID: Int32
    private let sepTokenID: Int32
    private let padTokenID: Int32

    init(vocabURL: URL) throws {
        let contents = try String(contentsOf: vocabURL, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var vocabulary: [String: Int32] = [:]
        for (index, token) in lines.enumerated() {
            vocabulary[token] = Int32(index)
        }
        self.vocabulary = vocabulary
        self.unknownTokenID = vocabulary["[UNK]"] ?? 100
        self.clsTokenID = vocabulary["[CLS]"] ?? 101
        self.sepTokenID = vocabulary["[SEP]"] ?? 102
        self.padTokenID = vocabulary["[PAD]"] ?? 0
    }

    func encode(_ text: String, maxLength: Int) -> (ids: [Int32], attentionMask: [Int32]) {
        let normalized = normalize(text)
        let words = split(normalized)
        var tokenIDs: [Int32] = [clsTokenID]

        for word in words {
            tokenIDs.append(contentsOf: tokenizeWord(word))
        }

        tokenIDs.append(sepTokenID)

        if tokenIDs.count > maxLength {
            tokenIDs = Array(tokenIDs.prefix(maxLength))
            if let lastIndex = tokenIDs.indices.last {
                tokenIDs[lastIndex] = sepTokenID
            }
        }

        var attentionMask = Array(repeating: Int32(1), count: tokenIDs.count)
        if tokenIDs.count < maxLength {
            let padding = maxLength - tokenIDs.count
            tokenIDs.append(contentsOf: Array(repeating: padTokenID, count: padding))
            attentionMask.append(contentsOf: Array(repeating: Int32(0), count: padding))
        }

        return (tokenIDs, attentionMask)
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private func split(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else {
                if !current.isEmpty {
                    tokens.append(current)
                    current.removeAll(keepingCapacity: true)
                }
                if !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                    tokens.append(String(scalar))
                }
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private func tokenizeWord(_ word: String) -> [Int32] {
        guard !word.isEmpty else {
            return []
        }

        if let fullID = vocabulary[word] {
            return [fullID]
        }

        let characters = Array(word)
        var pieces: [Int32] = []
        var start = 0

        while start < characters.count {
            var end = characters.count
            var matchedID: Int32?

            while start < end {
                let substring = String(characters[start..<end])
                let token = start == 0 ? substring : "##\(substring)"
                if let id = vocabulary[token] {
                    matchedID = id
                    break
                }
                end -= 1
            }

            guard let matchedID else {
                return [unknownTokenID]
            }

            pieces.append(matchedID)
            start = end
        }

        return pieces
    }
}
