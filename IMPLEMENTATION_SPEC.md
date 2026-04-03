# BGCategorizationProcessor Implementation Spec

## Purpose

`BGCategorizationProcessor` is an offline-first Swift Package Manager library for background-capable text categorization on iOS. It queues raw text, classifies it against consumer-managed categories using embedding-based cosine similarity, persists results, and allows asynchronous or polling-based result consumption.

## Constraints

- Swift 6 strict concurrency.
- Public API uses async/await only.
- SPM library with iOS 16+ minimum.
- Single SQLite database containing `categories`, `jobs`, and `categorization_results`.
- No third-party dependencies except SQLite access.
- Results are persisted for later retrieval and deleted when consumed.
- Latest categories at processing time are always used.

## Public API

```swift
public final class BGCategorizationProcessor: Sendable {
    public init(configuration: CategorizationConfiguration, embeddingProvider: EmbeddingProvider) throws

    public func addCategory(_ category: CategoryDefinition) async throws
    public func deleteCategory(id: String) throws
    public func resetCategories(to: [CategoryDefinition]) async throws
    public func currentCategories() throws -> [CategoryDefinition]

    public func enqueue(text: String, itemID: String, priority: JobPriority = .normal) async throws
    public func enqueue(batch: [(text: String, itemID: String)], priority: JobPriority = .normal) async throws
    public func pendingCount() throws -> Int

    public func results(limit: Int = 50) throws -> [CategorizationResult]
    public func result(for itemID: String) throws -> CategorizationResult?
    public func markConsumed(itemIDs: [String]) throws -> Int
    public var resultStream: AsyncStream<CategorizationResult> { get }

    public func processAvailableJobs(mode: ProcessingMode = .background) async throws
}
```

## Data Flow

1. `enqueue` persists jobs into SQLite and yields them to an internal stream.
2. `processAvailableJobs` purges expired results, loads category centroids, fetches queued jobs, and processes them.
3. If no categories exist, queued jobs produce empty-score results with `topCategory == nil`.
4. Successful classification writes a result and deletes the source job in one transaction.
5. Failed classification leaves the job in the queue.
6. Consumers fetch via `results(limit:)` or `result(for:)` and remove via `markConsumed(itemIDs:)`.

## Models

- `CategoryDefinition`
  - `id`
  - `label`
  - `descriptors`
- `CategorizationJob`
  - `itemID`
  - `text`
  - `priority`
  - `enqueuedAt`
- `CategorizationResult`
  - `itemID`
  - `categoryScores`
  - `topCategory`
  - `processedAt`
- `ClassificationConfig`
  - `minimumConfidence`
  - `sentencesPerChunk`
  - `maxTextLength`
- `CategorizationConfiguration`
  - `databasePath`
  - `classification`
  - `resultTTL`
  - `maxBatchSize`
  - `foregroundConcurrency`
- `ProcessingMode`
  - `.foreground`
  - `.background`
- `JobPriority`
  - `.low`
  - `.normal`
  - `.high`

## Categorization Rules

- Text is truncated to `maxTextLength`.
- Text is split into sentence-based chunks using `NLTokenizer`.
- Each chunk is embedded with the injected `EmbeddingProvider`.
- Scores are cosine similarity values against precomputed category centroids.
- Multi-chunk texts average category scores across chunks.
- `topCategory` is only assigned when the best score meets `minimumConfidence`.

## Category Rules

- Category centroids are computed at mutation time, not processing time.
- A centroid is the element-wise average of the label embedding plus all descriptor embeddings.
- If descriptors are empty, the centroid equals the label embedding.
- Category data and centroid JSON are stored together in SQLite.

## SQLite Schema

```sql
CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    descriptors_json TEXT NOT NULL,
    centroid_json TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS jobs (
    item_id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 1,
    enqueued_at REAL NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_jobs_priority_enqueued
ON jobs(priority DESC, enqueued_at ASC);

CREATE TABLE IF NOT EXISTS categorization_results (
    item_id TEXT PRIMARY KEY,
    category_scores_json TEXT NOT NULL,
    top_category TEXT,
    processed_at REAL NOT NULL
);
```

## Processing Modes

- `foreground`
  - Processes up to `maxBatchSize` jobs using a capped task group.
  - Concurrency is limited by `foregroundConcurrency`.
- `background`
  - Processes queued jobs sequentially.

## Error Rules

- Embedding failures skip jobs during processing.
- Database failures throw.
- Result JSON deserialization failures throw.
- Jobs are not deleted unless result insertion succeeds in the same transaction.

## Embedding Providers

- `EmbeddingProvider`
  - `embed(_:) async throws -> [Float]`
  - `dimensions`
- `NLEmbeddingProvider`
  - Uses `NaturalLanguage` sentence embeddings with detected-language and English fallback.
- `CoreMLEmbeddingProvider`
  - Uses a generic CoreML model plus WordPiece tokenization and mean pooling.

## Testing Expectations

- Engine scoring, chunking, thresholds, truncation, and embedding failures.
- Category CRUD and centroid persistence.
- Queue ordering, duplicate replacement, result round-trips, expiry, and transaction atomicity.
- Foreground concurrency and background ordering.
- Result stream emission.
- Full integration flow from category creation through result consumption.

## Implementation Note

The original draft spec described `CategorizationDatabase` as an actor while also requiring synchronous public reads and deletes. The shipped implementation keeps the public API shape and uses a thread-safe synchronous database layer instead of blocking actor bridging.
