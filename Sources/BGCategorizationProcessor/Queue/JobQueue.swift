import Foundation

actor JobQueue {
    private let database: CategorizationDatabase

    init(database: CategorizationDatabase) {
        self.database = database
    }

    func enqueue(_ job: CategorizationJob) async throws {
        try await database.insertJob(job)
    }

    func enqueueBatch(_ jobs: [CategorizationJob]) async throws {
        try await database.insertJobs(jobs)
    }

    func dequeue(limit: Int) async throws -> [CategorizationJob] {
        try await database.fetchJobs(limit: limit)
    }

    func remove(itemID: String) async throws {
        try await database.deleteJob(itemID: itemID)
    }
}
