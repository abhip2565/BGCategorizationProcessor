# BGCategorizationProcessor

An offline-first Swift package that categorizes text on-device using embeddings and cosine similarity. You define categories with descriptive keywords, queue up text, and the library figures out which category each piece of text belongs to — no network calls, no cloud APIs.

Everything is persisted in SQLite, so categories and results survive app restarts. It also integrates with iOS `BGTaskScheduler` to process queued work in the background while your app is suspended.

## Why this exists

Imagine you're building an app that receives text content (emails, notes, support tickets, articles) and you want to automatically sort it into buckets. You could send it to a server, but that means network dependency, latency, and privacy concerns. This library does it entirely on-device using sentence embeddings.

The flow is simple:

1. Define categories like "Finance", "Support", "Legal" with a few descriptor words each
2. Queue text for classification
3. The library embeds the text, compares it against category centroids, and gives you a ranked similarity score for each category

## Two products

| Product | What it gives you |
|---|---|
| `BGCategorizationProcessor` | The core library — queue management, SQLite storage, classification engine, background task coordination. Bring your own embedding provider. |
| `BGCategorizationProcessorCoreML` | A ready-to-use `CoreMLEmbeddingProvider` that ships a bundled MiniLM model (384-dimensional embeddings). Drop in and go. |

Most apps will want both. If you already have your own embedding model or want to use Apple's `NLEmbedding`, you can use just the core library and conform to `EmbeddingProvider`.

## Requirements

- iOS 16+ / macOS 13+
- Swift 6.0+

## Installation

Add the package to your project via SPM:

```swift
dependencies: [
    .package(url: "https://github.com/abhip2565/BGCategorizationProcessor.git", branch: "main")
]
```

Then add the products you need to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        "BGCategorizationProcessor",
        "BGCategorizationProcessorCoreML"  // if using the bundled CoreML model
    ]
)
```

## Quick start

### 1. Create the processor

```swift
import BGCategorizationProcessor
import BGCategorizationProcessorCoreML

let config = CategorizationConfiguration(
    databasePath: "/path/to/your/database.sqlite3",
    backgroundTaskIdentifier: "com.yourapp.categorization"  // optional, enables BG processing
)

let provider = try CoreMLEmbeddingProvider()
let processor = try BGCategorizationProcessor(
    configuration: config,
    embeddingProvider: provider
)
```

If you pass a `backgroundTaskIdentifier`, the library automatically registers with `BGTaskScheduler` and handles background processing for you. More on that below.

### 2. Define categories

```swift
let finance = CategoryDefinition(
    id: "finance",
    label: "Finance",
    descriptors: ["invoice", "expense report", "tax filing", "budget review"]
)

try await processor.addCategory(finance)
```

Descriptors are short phrases that describe what belongs in the category. The library embeds them and averages the vectors into a centroid — think of it as the "center point" of that category in embedding space.

You can also bulk-load:

```swift
try await processor.resetCategories(to: [finance, support, legal, travel])
```

### 3. Queue text for classification

```swift
// Single item
try await processor.enqueue(text: emailBody, itemID: "email-123", priority: .high)

// Batch
try await processor.enqueue(batch: [
    (text: article1, itemID: "article-1"),
    (text: article2, itemID: "article-2"),
], priority: .normal)
```

Each `itemID` is your own identifier — use whatever makes sense for your domain.

### 4. Process the queue

If you set up a `backgroundTaskIdentifier`, the library processes automatically in both foreground and background. But you can also trigger it manually:

```swift
// Process one batch
try await processor.processAvailableJobs(mode: .foreground)

// Or drain everything
while try await processor.pendingCount() > 0 {
    try await processor.processAvailableJobs(mode: .foreground)
}
```

Foreground mode processes jobs in parallel (configurable concurrency). Background mode processes sequentially to be gentle on resources.

### 5. Get results

```swift
// Fetch a specific result
if let result = try await processor.result(for: "email-123") {
    print(result.topCategory)      // "finance" (or nil if nothing crossed the threshold)
    print(result.categoryScores)   // ["finance": 0.72, "support": 0.31, "legal": 0.18, ...]
}

// Fetch recent results
let recent = try await processor.results(limit: 20)

// Stream results as they come in
for await result in processor.resultStream {
    print("Classified \(result.itemID) as \(result.topCategory ?? "unknown")")
}
```

### 6. Clean up consumed results

Once you've acted on results, mark them as consumed so they don't pile up:

```swift
try await processor.markConsumed(itemIDs: ["email-123", "email-456"])
```

Results also auto-expire based on `resultTTL` (default: 24 hours).

## Configuration

```swift
CategorizationConfiguration(
    databasePath: String?,              // where to store the SQLite database (has a sensible default)
    classification: ClassificationConfig(
        minimumConfidence: 0.30,        // below this, topCategory returns nil
        sentencesPerChunk: 5,           // how many sentences per embedding chunk
        maxTextLength: 50_000           // truncate text beyond this length
    ),
    resultTTL: 86_400,                  // seconds before results auto-expire (24h)
    foregroundBatchSize: 50,            // jobs per batch in foreground mode
    backgroundBatchSize: 5,             // jobs per batch in background mode
    foregroundConcurrency: 4,           // parallel jobs in foreground mode
    backgroundTaskIdentifier: String?   // set this to enable BGTaskScheduler integration
)
```

## Background processing

If you provide a `backgroundTaskIdentifier`, the library handles everything:

1. Registers a `BGProcessingTask` handler on init
2. Schedules background work whenever jobs are enqueued
3. Processes jobs sequentially in the background (respects system time limits)
4. Reschedules automatically if work remains when the system reclaims time

Your app's `Info.plist` needs two entries:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.yourapp.categorization</string>
</array>
```

To test background processing during development, use the debugger command after minimizing your app:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.yourapp.categorization"]
```

The library includes `os.log` debug logging under the `BGCategorizationProcessor` subsystem. Filter by `category:BGTaskCoordinator` in Console to see task lifecycle events.

## Custom embedding providers

If you don't want to use the bundled CoreML model, conform to `EmbeddingProvider`:

```swift
public protocol EmbeddingProvider: Sendable {
    func embed(_ text: String) async throws -> [Float]
    var dimensions: Int { get }
}
```

The core library also ships `NLEmbeddingProvider` which uses Apple's `NLEmbedding` (512 dimensions, no bundled model needed). The CoreML provider uses MiniLM (384 dimensions) which tends to produce better similarity scores for short-to-medium text.

## How classification works

Under the hood:

1. Long text gets chunked into groups of N sentences (configurable)
2. Each chunk is embedded into a vector
3. Chunk vectors are averaged into a single document vector
4. The document vector is compared against each category's centroid using cosine similarity
5. If the highest score exceeds `minimumConfidence`, that category wins

Category centroids are computed by embedding the category label + all descriptor phrases and averaging those vectors. This happens once when you add/update a category — the centroid is persisted in SQLite.

## Architecture

```
BGCategorizationProcessor (core)
  ├── Models/          — CategoryDefinition, CategorizationResult, CategorizationJob, configs
  ├── Engine/          — CategorizationEngine, TextChunker, CosineSimilarity, EmbeddingProvider
  ├── Queue/           — JobQueue (priority-based, FIFO within priority)
  ├── Storage/         — SQLite via DatabaseConnection + CategorizationDatabase
  ├── BGTaskCoordinator — BGTaskScheduler registration and lifecycle
  └── AppStateObserver  — Foreground/background state tracking

BGCategorizationProcessorCoreML
  └── CoreMLEmbeddingProvider — Bundled MiniLM .mlmodelc
```

Everything is `Sendable`. The processor itself is a `class` (not an actor) but uses an internal `ProcessingGate` actor to prevent concurrent batch processing, and an `AutomaticProcessingDriver` to manage the foreground drain loop.

## Tests

The package includes 71 tests covering:

- Cosine similarity math
- Text chunking edge cases
- Category CRUD operations
- Database persistence and migrations
- Processing modes (foreground parallel vs. background sequential)
- Embedding provider conformance (both NL and CoreML)
- End-to-end integration tests
- Model calibration and real-model accuracy tests

Run them with:

```sh
swift test
```

CoreML embedding tests require a macOS host with Apple Silicon (the MiniLM model is ARM-only).

## Sample app

There's a full SwiftUI sample app in [`SampleApp/`](SampleApp/README.md) that demonstrates everything — category management, text classification, background task testing with a 500-job stress test, and a diagnostics panel. See its README for setup instructions.

## License

MIT
