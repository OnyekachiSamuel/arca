# Task Ownership Retain Cycle

### Task Ownership

**Check for:**
- [ ] An object stores a long-running or repeating `Task`
- [ ] The stored task strongly captures that object
- [ ] The cycle can prevent owner deallocation

**Do not flag:**
- [ ] A short-lived unstored task
- [ ] A weak owner capture
- [ ] A design with independently guaranteed termination

**Examples:**

❌ **Bad: Owner and task retain each other**
```swift
@MainActor
final class ImageLoader {
    var task: Task<Void, Never>?
    
    func startPolling() {
        task = Task {
            while true {
                self.pollImages() // ⚠️ Strong capture
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

var loader: ImageLoader? = .init()
loader?.startPolling()
loader = nil // ⚠️ Loader never deallocated - retain cycle!
```

✅ **Good: Weak owner capture**
```swift
func startPolling() {
    task = Task { [weak self] in
        while let self = self {
            self.pollImages()
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

var loader: ImageLoader? = .init()
loader?.startPolling()
loader = nil // ✅ Loader deallocated, task stops
```
