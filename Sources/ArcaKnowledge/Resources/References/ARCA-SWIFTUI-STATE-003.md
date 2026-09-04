# Improper Async Work Lifecycle in SwiftUI View

### .task vs .onAppear for Async Work

**Check for:**
- [ ] .task modifier for async work instead of .onAppear
- [ ] Automatic cancellation handling with .task
- [ ] No manual Task creation in .onAppear

**Examples:**

❌ **Bad: .onAppear with manual Task**
```swift
.onAppear {
    Task {  // ❌ Manual task, no automatic cancellation
        await viewModel.load()
    }
}
```

✅ **Good: .task modifier**
```swift
.task {  // ✅ Automatically cancelled when view disappears
    await viewModel.load()
}
```

✅ **Good: .task with id for refresh**
```swift
.task(id: selectedCategory) {  // ✅ Runs again when id changes
    await viewModel.load(category: selectedCategory)
}
```