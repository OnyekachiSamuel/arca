# God Object

### Focused Type Responsibility

**Check for:**
- [ ] The type has one focused responsibility
- [ ] Its properties and methods support the same concern
- [ ] It does not own unrelated networking, persistence, navigation, analytics, and business responsibilities
- [ ] Dependencies are used for one cohesive purpose
- [ ] Size or naming alone is not treated as proof of a God Object

**Examples:**

❌ **Bad: Multiple unrelated responsibilities**
```swift
final class ApplicationManager {
    private var accessToken: String?
    private var cachedUsers: [User] = []
    private var currentRoute: Route?

    func authenticate(
        username: String,
        password: String
    ) async throws {
        accessToken = try await authenticationAPI.login(
            username: username,
            password: password
        )
    }

    func saveUsers() throws {
        try database.save(cachedUsers)
    }

    func showProfile() {
        currentRoute = .profile
        router.navigate(to: .profile)
    }

    func trackLogin() {
        analytics.track("user_login")
    }
}
```

✅ **Good: One cohesive responsibility**
```swift
final class AuthenticationService {
    private var accessToken: String?

    func authenticate(
        username: String,
        password: String
    ) async throws {
        accessToken = try await authenticationAPI.login(
            username: username,
            password: password
        )
    }

    func refreshSession() async throws {
        accessToken = try await authenticationAPI.refresh(
            token: accessToken
        )
    }

    func logout() {
        accessToken = nil
    }
}
```