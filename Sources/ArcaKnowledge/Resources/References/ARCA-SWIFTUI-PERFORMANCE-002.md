# Unnecessary GeometryReader Usage

### GeometryReader Overuse

**Check for:**
- [ ] Minimal GeometryReader usage
- [ ] No nested GeometryReaders
- [ ] Use .frame(maxWidth:) instead when possible

**Examples:**

❌ **Bad: Unnecessary GeometryReader**
```swift
GeometryReader { geometry in  // ❌ Not needed
    VStack {
        Text("Hello")
            .frame(width: geometry.size.width)
    }
}
```

✅ **Good: Simple frame modifier**
```swift
VStack {
    Text("Hello")
        .frame(maxWidth: .infinity)  // ✅ Much simpler
}
```

❌ **Bad: Nested GeometryReaders**
```swift
GeometryReader { outerGeometry in
    VStack {
        ForEach(items) { item in
            GeometryReader { innerGeometry in  // ❌ Nested, performance issue
                ItemView(item: item, width: innerGeometry.size.width)
            }
        }
    }
}
```

✅ **Good: Single GeometryReader**
```swift
// Single GeometryReader
GeometryReader { geometry in
    VStack {
        ForEach(items) { item in
            ItemView(item: item, width: geometry.size.width)  // ✅ Reuse outer
        }
    }
}
```