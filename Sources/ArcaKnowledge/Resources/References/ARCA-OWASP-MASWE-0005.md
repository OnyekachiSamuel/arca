# Insertion of Sensitive Data into Logs

## Sensitive Data Logging

Sensitive data may include:

- [ ] Passwords and credentials
- [ ] Authentication or session tokens
- [ ] Cryptographic keys
- [ ] Payment or other sensitive user information

**Check for:**

- [ ] Sensitive data passed to `print`, `debugPrint`, `dump`, or similar console-output APIs
- [ ] Sensitive data passed to `NSLog` or Unified Logging APIs
- [ ] Credentials or authentication tokens included in diagnostic messages
- [ ] Sensitive values written through custom or third-party logging frameworks
- [ ] Verbose or debug logging that exposes sensitive information

### Examples

❌ **Bad: Logging credentials**

```swift
func login(username: String, password: String) {
    print("Logging in user: \(username), password: \(password)")
}
```

❌ Bad: Logging an authentication token

```swift
func handleLoginResponse(token: String) {
    debugPrint("Authentication successful. Token: \(token)")
}
```

❌ Bad: Sensitive data through a logger

```swift
func storeToken(_ token: String) {
    logger.debug("Saving authentication token: \(token)")
}
```

✅ Good: Log the event without the sensitive value

```swift
func handleLoginResponse(token: String) {
    logger.info("Authentication completed successfully")
}
```