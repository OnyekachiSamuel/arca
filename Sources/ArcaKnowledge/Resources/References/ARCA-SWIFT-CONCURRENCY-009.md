# Unobserved Throwing Task-Group Failure

### Task-Group Errors

**Check for:**
- [ ] `withThrowingTaskGroup` creates throwing children
- [ ] The group never retrieves child results through a throwing operation

**Do not flag:**
- [ ] `for try await`, `try await group.next()`, or a throwing reduction consumes results
- [ ] A nonthrowing task group

**Examples:**

❌ **Bad: Child failure is not observed**
```swift
try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask {
        try await uploadBackup()
    }
}
```

✅ **Good: Iteration propagates child errors**
```swift
let images = try await withThrowingTaskGroup(of: UIImage.self) { group in
    for url in photoURLs {
        group.addTask { try await downloadPhoto(url: url) }
    }
    
    // Iterate to propagate errors
    var results: [UIImage] = []
    for try await image in group {
        results.append(image)
    }
    return results
}
```
