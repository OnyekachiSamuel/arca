# Incomplete AsyncStream Lifecycle

### Stream Termination

**Check for:**
- [ ] The file establishes that the stream is finite and shows a terminal path without `finish()`
- [ ] Or the file creates a bridged resource whose cleanup responsibility is visible
- [ ] No matching `onTermination` cleanup is visible for that resource

**Do not flag:**
- [ ] An intentionally infinite stream solely because it lacks `finish()`
- [ ] Streams that finish on all terminal paths
- [ ] Bridges that release resources on termination
- [ ] Finiteness or cleanup responsibility inferred only from external code

**Examples:**

❌ **Bad: Finite stream never finishes**
```swift
// ❌ Forgot to finish
AsyncStream { continuation in
    continuation.yield(1)
    // Stream never ends!
}
```

✅ **Good: Finite stream finishes**
```swift
// ✅ Always finish
AsyncStream { continuation in
    continuation.yield(1)
    continuation.finish()
}
```

✅ **Good: Termination releases resources**
```swift
AsyncThrowingStream<Int, Error> { continuation in
    continuation.onTermination = { @Sendable reason in
        print("Terminated: \(reason)")
        // Cleanup: remove observers, cancel work, etc.
    }
    
    continuation.yield(1)
    continuation.finish()
}
```
