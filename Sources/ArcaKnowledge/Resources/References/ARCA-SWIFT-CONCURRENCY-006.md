# Non-Sendable Value Crossing an Isolation Boundary

### Ownership Transfer

**Check for:**
- [ ] The file visibly establishes that the value is non-Sendable
- [ ] The value crosses an actor or task boundary
- [ ] The original region continues to access it
- [ ] No valid ownership transfer is used

**Do not flag:**
- [ ] Sendable values
- [ ] Values kept within one isolation region
- [ ] Valid `sending` ownership transfer
- [ ] Values whose Sendable status depends on a declaration outside the file

**Examples:**

```swift
class Article {
    var title: String
    init(title: String) { self.title = title }
}
```

❌ **Bad: Value is accessed after transfer**
```swift
func check() {
    let article = Article(title: "Swift")
    
    Task {
        print(article.title)
    }
    
    print(article.title) // ❌ Error - accessed after transfer
}
```

✅ **Good: Explicit ownership transfer**
```swift
actor Logger {
    func log(article: Article) {
        print(article.title)
    }
}

func printTitle(article: sending Article) async {
    let logger = Logger()
    await logger.log(article: article)
}

// Usage
let article = Article(title: "Swift")
await printTitle(article: article)
// article no longer accessible here
```
