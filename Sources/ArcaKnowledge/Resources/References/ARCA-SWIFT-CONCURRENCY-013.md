# Multiple Consumers of a Single AsyncStream

### Stream Consumption

**Check for:**
- [ ] The same `AsyncStream` instance is iterated by multiple tasks
- [ ] The file visibly establishes that each consumer must receive every element

**Do not flag:**
- [ ] Separate stream instances
- [ ] Intentional work distribution
- [ ] A broadcast-capable abstraction
- [ ] Multiple consumers without visible broadcast intent
- [ ] Broadcast intent inferred only from external callers or naming

**Example:**

❌ **Bad: Two consumers expect broadcast delivery**
```swift
let stream = AsyncStream { continuation in
    (0...5).forEach { continuation.yield($0) }
    continuation.finish()
}

Task {
    for await value in stream {
        print("Consumer 1: \(value)")
    }
}

Task {
    for await value in stream {
        print("Consumer 2: \(value)")
    }
}

// Unpredictable output - values split between consumers
// Consumer 1: 0
// Consumer 2: 1
// Consumer 1: 2
// Consumer 2: 3
```
