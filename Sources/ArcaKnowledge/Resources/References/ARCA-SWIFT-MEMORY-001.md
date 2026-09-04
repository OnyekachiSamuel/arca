
# Strong Reference Cycle in Closure Capture

### Retain Cycles

**Check for:**
- [ ] No strong reference cycles with closures
- [ ] [weak self] in closures when necessary
- [ ] Proper capture lists

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