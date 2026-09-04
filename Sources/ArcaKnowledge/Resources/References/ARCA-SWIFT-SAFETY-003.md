# Unjustified Force Try

### Force Try Audit

**Check for:**
- [ ] No `try!` (force try) unless absolutely justified
- [ ] Proper error handling with do-catch or Result
- [ ] Comments explaining any necessary force tries

**Examples:**

❌ **Bad: Force try**
```swift
let user = try! decoder.decode(User.self, from: data)  // ❌ Can crash!
```

✅ **Good: Proper error handling**
```swift
do {
    let user = try decoder.decode(User.self, from: data)
    return user
} catch {
    logger.error("Failed to decode user: \(error)")
    return nil
}
```

✅ **Acceptable: Force try with justification**
```swift
// Static JSON bundled with app - guaranteed to be valid
let defaultConfig = try! decoder.decode(
    Config.self,
    from: bundledJSONData
)  // Force try justified: bundled resource
```