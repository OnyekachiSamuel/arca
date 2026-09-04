# Heavy Computation in SwiftUI View Body

## Heavy Computation in Body

**Check for:**
- [ ] Sorting, filtering, or mapping in body
- [ ] Network calls or database queries in body
- [ ] Complex calculations during render

**Examples:**

❌ **Bad: Computation in body**
```swift
struct ItemListView: View {
    let items: [Item]

    var body: some View {
        let filtered = items.filter { $0.isActive }  // ❌ Every render
        let sorted = filtered.sorted { $0.date > $1.date }  // ❌ Every render

        List(sorted) { item in
            ItemRow(item: item)
        }
    }
}
```

✅ **Good: Computed property**
```swift
struct ItemListView: View {
    let items: [Item]

    private var processedItems: [Item] {  // ✅ Computed property
        items
            .filter { $0.isActive }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List(processedItems) { item in
            ItemRow(item: item)
        }
    }
}
```

✅ **Better: View model handles logic**
```swift
@Observable
final class ItemListViewModel {
    var items: [Item] = []
    var showActiveOnly: Bool = true

    var displayedItems: [Item] {  // ✅ Cached by view model
        let filtered = showActiveOnly ? items.filter { $0.isActive } : items
        return filtered.sorted { $0.date > $1.date }
    }
}

struct ItemListView: View {
    let viewModel: ItemListViewModel

    var body: some View {
        List(viewModel.displayedItems) { item in  // ✅ Already processed
            ItemRow(item: item)
        }
    }
}
```