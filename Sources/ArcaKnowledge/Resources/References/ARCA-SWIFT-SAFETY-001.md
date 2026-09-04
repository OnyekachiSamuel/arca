# Force Unwrapping of Optionals

### Force Unwrap Audit

**Check for:**
- [ ] No force unwrapping (`!`) unless absolutely justified
- [ ] Comments explaining any necessary force unwraps

**Examples:**

❌ **Bad: Force unwrap**
```swift
let user = userRepository.currentUser!  // ❌ Can crash!
let name = user.name!
```

✅ **Good: Guard statement**
```swift
guard let user = userRepository.currentUser else {
    logger.error("No current user")
    return
}
let name = user.name ?? "Unknown"
```

✅ **Good: If-let binding**
```swift
if let user = userRepository.currentUser {
    displayUser(user)
} else {
    showLoginScreen()
}
```

✅ **Good: Optional chaining**
```swift
let username = userRepository.currentUser?.name ?? "Guest"
```