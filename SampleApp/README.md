# Sample App

A SwiftUI iOS app that puts `BGCategorizationProcessor` through its paces. Use it to play with categories, classify text, and stress-test background processing on a real device.

## What you can do

### Classify tab
- Pick from quick sample texts or type your own
- Hit **Classify** and see which category wins, along with a ranked similarity map showing how every category scored
- The similarity map uses color intensity to visualize confidence — brighter means higher match

### Categories tab
- Add, edit, and delete categories with custom descriptor phrases
- **Seed 30 starter categories** with one tap — covers finance, support, travel, legal, engineering, marketing, HR, security, data, logistics, and 20 more
- Categories persist in SQLite, so they survive app kills and restarts

### Diagnostics tab
- See runtime status at a glance: lifecycle state, background refresh availability, pending job count, category count, last processed item
- **Queue 500 jobs for BG processing** — enqueues 500 large-text jobs (~20k chars each) without processing them, so you can test `BGTaskScheduler` picking up the work in the background
- **Run 500-job stress test (foreground)** — enqueues and immediately processes all 500 jobs, showing live progress and a scrollable results list with category, job index, and confidence score
- **Process pending in foreground** — drains whatever is left in the queue
- **Consume visible results** — marks displayed results as consumed to clear them out
- **Refresh snapshot** — re-reads the database state

## Getting started

### 1. Open the project

```sh
cd SampleApp
open BGCategorizationProcessorSampleApp.xcodeproj
```

The project pulls the package from GitHub via SPM:

```
https://github.com/abhip2565/BGCategorizationProcessor.git
```

Wait for Xcode to resolve the package, then build and run.

### 2. Seed categories

Go to the **Categories** tab and tap **Seed Starter Categories**. This loads 30 categories spanning different domains. You can also add your own.

### 3. Try a classification

Go to the **Classify** tab, pick a sample text (or paste your own), and tap **Classify**. You'll see:
- The winning category (or "No confident category" if nothing crossed the threshold)
- A similarity map ranking all 30 categories by score

### 4. Stress test

Go to the **Diagnostics** tab. You have two options:

**Foreground stress test** — Tap "Run 500-job stress test (foreground)". This enqueues and processes all 500 jobs inline. Watch the progress counter and browse the results list when it finishes. Good for benchmarking throughput.

**Background stress test** — Tap "Queue 500 jobs for BG processing". This only enqueues the jobs. Then:

1. Minimize the app (swipe home)
2. In Xcode's lldb console, paste:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.abhip2565.BGCategorizationProcessor.sample.processing"]
```

3. Watch the debug logs in Console (filter: `subsystem:BGCategorizationProcessor`)
4. Reopen the app — pending count should be dropping and results appearing

## Debug logging

The library logs BGTask lifecycle events using `os.log`. Filter in Xcode console or Console.app:

```
subsystem:BGCategorizationProcessor
```

You'll see:
- When the task handler is registered
- When a `BGProcessingTaskRequest` is scheduled
- When the system launches the background task
- Batch-by-batch progress (batch number + remaining jobs)
- Whether the system's expiration handler fired
- Final summary (jobs processed, jobs remaining)

## Info.plist configuration

The sample app's `Info.plist` is already set up with:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.abhip2565.BGCategorizationProcessor.sample.processing</string>
</array>
```

Both are required for `BGTaskScheduler` to work. If either is missing, the diagnostics panel will tell you.

## How the stress test texts work

The 500 test jobs cycle across 10 text domains (finance, support, travel, legal, engineering, marketing, HR, security, data, logistics). Each job is built by looping rich paragraphs until the text exceeds 20,000 characters. This gives you realistic-length documents that exercise the chunking, embedding, and scoring pipeline end to end.

With 30 categories and 10 text domains, you'll see a good spread of category matches in the results — not everything lands in the same bucket.

## Classification config

The sample app uses:

| Setting | Value |
|---|---|
| Minimum confidence | 0.35 |
| Sentences per chunk | 5 |
| Max text length | 25,000 |
| Foreground batch size | 24 |
| Background batch size | 5 |
| Foreground concurrency | 3 |

These are tuned for the sample app's workload. Your app may want different values — see the main library README for what each setting does.

## Important notes

- **Real device required** for background task testing. The Simulator doesn't reliably fire `BGProcessingTask`.
- **Background App Refresh** must be enabled in Settings > General > Background App Refresh for your app.
- The app consumes the package from the **remote GitHub URL**, not the local checkout. If you're iterating on the library locally, update the package dependency in Xcode to point to your local path.
