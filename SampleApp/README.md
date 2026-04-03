# Sample App

This folder contains a standalone SwiftUI iOS sample app for `BGCategorizationProcessorCoreML`.

## What it demonstrates

- Full category CRUD backed by the library's persisted SQLite store
- Manual text classification with explicit enqueue + foreground processing
- Ranked category rendering with a highlighted winner and similarity-based color intensity
- Background-processing diagnostics, pending-job inspection, and a manual device validation flow

## Dependency strategy

The app project resolves the package through:

`https://github.com/abhip2565/BGCategorizationProcessor.git`

That matches the requested integration shape for consumers. For local package development, remember that the sample app will build against the remote package reference until you update the package dependency in Xcode.

## Generate the project

Run from this folder:

```sh
xcodegen generate
```

Then open `BGCategorizationProcessorSampleApp.xcodeproj`.

## Background mode notes

- The sample app declares `processing` in `UIBackgroundModes`.
- The sample app includes a `BGTaskSchedulerPermittedIdentifiers` entry for `com.abhip2565.BGCategorizationProcessor.sample.processing`.
- Real background-processing validation should be done on a physical device with Background App Refresh enabled.
