
# Hard-Coded Singleton Dependency

### Constructor Injection

**Check for:**
- [ ] Dependencies passed via initializer
- [ ] Protocol-based dependencies (testable)
- [ ] No service locator or singletons

**Examples:**

❌ **Bad: Singleton dependency**
```swift
final class UserViewModel {
    func loadUsers() async {
        // ❌ Hard dependency on singleton
        let users = try await NetworkService.shared.fetchUsers()
    }
}
```

✅ **Good: Constructor injection**
```swift
final class UserViewModel {
    private let userRepository: UserRepository  // ✅ Protocol

    init(userRepository: UserRepository) {  // ✅ Injected
        self.userRepository = userRepository
    }

    func loadUsers() async {
        let users = try await userRepository.fetchUsers()
    }
}

// Usage
let viewModel = UserViewModel(
    userRepository: DefaultUserRepository(
        networkClient: networkClient,
        database: database,
        cache: cache
    )
)
```