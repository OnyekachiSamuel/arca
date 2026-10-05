
# Hard-Coded Singleton Dependency

### Constructor Injection

**Check for:**
- [ ] A component obtains a service through `.shared`, `.standard`, a global variable, or a service locator
- [ ] The service provides operational behaviour
- [ ] The service is not received through an explicit replaceable boundary

**Do not flag:**
- [ ] Access to a stored instance property through `self`
- [ ] A dependency supplied through an initializer or parameter
- [ ] A singleton declaration by itself
- [ ] Shared constants or configuration values
- [ ] A type accessing its own shared actor instance

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
