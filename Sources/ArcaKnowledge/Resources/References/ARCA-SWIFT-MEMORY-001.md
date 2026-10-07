
# Strong Reference Cycle in Closure Capture

### Retain Cycles

**Check for:**
- [ ] An object stores or strongly retains a closure
- [ ] That closure strongly captures the same object through `self`
- [ ] The resulting ownership cycle is visible in the source

**Do not flag:**
- [ ] A `Task` closure merely because it references an object
- [ ] Stored `Task` ownership cycles covered by `ARCA-SWIFT-CONCURRENCY-011`
- [ ] A closure that does not capture `self`

**Examples:**

❌ **Bad: Retain cycle**
```swift
@Observable
final class ViewModel {
    var onComplete: (() -> Void)?

    func setup() {
        onComplete = {
            self.finish()  // ❌ Retain cycle
        }
    }

    func finish() { }
}
```

✅ **Good: Weak self**
```swift
@Observable
final class ViewModel {
    var onComplete: (() -> Void)?

    func setup() {
        onComplete = { [weak self] in  // ✅ Weak capture
            self?.finish()
        }
    }

    func finish() { }
}
```

✅ **Good: Unowned for guaranteed lifetime**
```swift
@Observable
final class ViewModel {
    let dependency: Dependency

    func setup() {
        dependency.onEvent = { [unowned self] in  // ✅ Unowned when guaranteed
            self.handleEvent()
        }
    }
}
```
