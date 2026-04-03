import XCTest
@testable import BGCategorizationProcessor

final class CategoryCRUDTests: XCTestCase {
    private var tempDirectory: URL!
    private var databasePath: String!

    override func setUp() {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        databasePath = tempDirectory.appendingPathComponent("categories.sqlite3").path
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testAddCategoryPersistsDefinitionAndCentroid() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: [
            "finance": [1, 0, 0, 0],
            "tax": [1, 0, 0, 0],
            "invoice": [1, 0, 0, 0]
        ]))

        try await processor.addCategory(
            CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"])
        )

        let categories = try await processor.currentCategories()
        XCTAssertEqual(categories.count, 1)

        let database = try CategorizationDatabase(path: databasePath)
        let centroids = try await database.loadCentroids()
        XCTAssertEqual(centroids["finance"], [1, 0, 0, 0])
    }

    func testDeleteCategoryRemovesIt() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: [
            "finance": [1, 0, 0, 0]
        ]))

        try await processor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: []))
        try await processor.deleteCategory(id: "finance")
        let afterDelete = try await processor.currentCategories()
        XCTAssertTrue(afterDelete.isEmpty)
    }

    func testResetCategoriesReplacesAll() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: [
            "finance": [1, 0, 0, 0],
            "health": [0, 1, 0, 0]
        ]))

        try await processor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: []))
        try await processor.resetCategories(to: [
            CategoryDefinition(id: "health", label: "health", descriptors: [])
        ])

        let categories = try await processor.currentCategories()
        XCTAssertEqual(categories.map(\.id), ["health"])
    }

    func testEmptyDescriptorsUseLabelEmbedding() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: [
            "finance": [1, 0, 0, 0]
        ]))

        try await processor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: []))
        let database = try CategorizationDatabase(path: databasePath)
        let centroids = try await database.loadCentroids()
        XCTAssertEqual(centroids["finance"], [1, 0, 0, 0])
    }

    func testDuplicateCategoryIDReplacesExisting() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: [
            "finance": [1, 0, 0, 0],
            "money": [0.5, 0.5, 0, 0]
        ]))

        try await processor.addCategory(CategoryDefinition(id: "category", label: "finance", descriptors: []))
        try await processor.addCategory(CategoryDefinition(id: "category", label: "money", descriptors: []))

        let categories = try await processor.currentCategories()
        XCTAssertEqual(categories.first?.label, "money")
    }

    func testDeleteNonexistentCategoryIsIdempotent() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider())
        try await processor.deleteCategory(id: "missing")
    }

    func testCurrentCategoriesReturnsAllCategories() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: [
            "finance": [1, 0, 0, 0],
            "health": [0, 1, 0, 0]
        ]))

        try await processor.resetCategories(to: [
            CategoryDefinition(id: "finance", label: "finance", descriptors: []),
            CategoryDefinition(id: "health", label: "health", descriptors: [])
        ])

        let categories = try await processor.currentCategories()
        XCTAssertEqual(Set(categories.map(\.id)), Set(["finance", "health"]))
    }

    func testCategoriesPersistAcrossProcessorReinitialization() async throws {
        let vectors: [String: [Float]] = [
            "Finance": [1, 0, 0, 0],
            "invoice": [1, 0, 0, 0],
            "Travel": [0, 1, 0, 0],
            "boarding pass": [0, 1, 0, 0]
        ]

        let firstProcessor = try makeProcessor(provider: MockEmbeddingProvider(vectors: vectors))
        try await firstProcessor.resetCategories(to: [
            CategoryDefinition(id: "finance", label: "Finance", descriptors: ["invoice"]),
            CategoryDefinition(id: "travel", label: "Travel", descriptors: ["boarding pass"])
        ])

        let secondProcessor = try makeProcessor(provider: MockEmbeddingProvider(vectors: vectors))
        let persisted = try await secondProcessor.currentCategories()

        XCTAssertEqual(
            persisted.sorted { $0.id < $1.id }.map(\.id),
            ["finance", "travel"]
        )
    }

    func testLoadCentroidsReturnsMap() async throws {
        let database = try CategorizationDatabase(path: databasePath)
        try await database.upsertCategory(
            CategoryDefinition(id: "finance", label: "finance", descriptors: []),
            centroid: [1, 0, 0, 0]
        )

        let centroids = try await database.loadCentroids()
        XCTAssertEqual(centroids["finance"], [1, 0, 0, 0])
    }

    private func makeProcessor(provider: MockEmbeddingProvider) throws -> BGCategorizationProcessor {
        try BGCategorizationProcessor(
            configuration: CategorizationConfiguration(databasePath: databasePath),
            embeddingProvider: provider
        )
    }
}
