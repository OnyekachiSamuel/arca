# Unprotected Mutable Global or Static State

### Global State

**Check for:**
- [ ] Mutable global or static stored state
- [ ] Access from multiple visible concurrency contexts
- [ ] No isolation or synchronization
- [ ] The stored global or static value itself is read or written

**Do not flag:**
- [ ] Immutable static state
- [ ] Instance state
- [ ] A shared reference whose underlying instance state is covered by ARCA-SWIFT-CONCURRENCY-001
- [ ] Global-actor-isolated or synchronized state

**Examples:**

❌ **Bad: Concurrent access to mutable static state**
```swift
final class ImageCache {
    static var images: [URL: Data] = [:]
}

Task { ImageCache.images[url] = data }
Task { ImageCache.images.removeValue(forKey: url) }
```

✅ **Good: Global-actor isolation**
```swift
@MainActor
class ImageCache {
    static var shared = ImageCache()
}
```
