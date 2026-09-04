# Sensitive Data Stored Unencrypted in Private Storage

## Sensitive Data in Private Storage

Sensitive data may include:

- [ ] Credentials and passwords
- [ ] Authentication or session tokens
- [ ] Cryptographic keys
- [ ] Personally identifiable information (PII)

**Check for:**

- [ ] Sensitive data written unencrypted to application-private storage
- [ ] Sensitive data stored directly in `UserDefaults`
- [ ] Sensitive data written as plaintext to files in the application sandbox
- [ ] Sensitive data persisted unprotected through local databases such as Core Data or SQLite
- [ ] Credentials, tokens, or cryptographic material stored outside an appropriate secure storage mechanism such as the iOS Keychain

### Examples

❌ **Bad: Authentication token stored in UserDefaults**

```swift
func saveToken(_ token: String) {
    UserDefaults.standard.set(token, forKey: "authToken")
}
```

❌ Bad: Sensitive data written to a plaintext file

```swift
func saveCredentials(_ credentials: String) throws {
    let url = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("credentials.txt")

    try credentials.write(
        to: url,
        atomically: true,
        encoding: .utf8
    )
}
```
✅ Good: Sensitive credential stored using Keychain

```swift

func saveToken(_ token: String) throws {
    let data = Data(token.utf8)

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "authToken",
        kSecValueData as String: data,
        kSecAttrAccessible as String:
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]

    SecItemAdd(query as CFDictionary, nil)
}
```