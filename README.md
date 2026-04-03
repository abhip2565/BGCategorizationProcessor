# BGCategorizationProcessor

`BGCategorizationProcessor` is an offline-first Swift package for queueing text, categorizing it against persisted category centroids, and retrieving results later from SQLite-backed storage.

## Products

- `BGCategorizationProcessor`
- `BGCategorizationProcessorCoreML`

## Sample App

The repository now includes a SwiftUI sample app in [SampleApp](SampleApp/README.md) that demonstrates:

- full category CRUD
- manual text classification with the CoreML product
- persisted categories surviving relaunch and app kill
- a diagnostics panel for background-processing validation

Generate the sample app project with:

```sh
cd SampleApp
xcodegen generate
```

The sample app project is configured to consume the package from:

`https://github.com/abhip2565/BGCategorizationProcessor.git`

## Background validation

The package already contains integration coverage for queueing and processing behavior. The sample app adds a device-oriented manual validation path for background processing because `BGTaskScheduler` behavior is system-managed and not reliably reproducible in simulator-only testing.
