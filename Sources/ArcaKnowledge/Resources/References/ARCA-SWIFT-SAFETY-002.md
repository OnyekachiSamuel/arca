# Unnecessary Implicitly Unwrapped Optional

### Implicitly Unwrapped Optionals

**Check for:**
- [ ] Avoid `!` declarations unless absolutely necessary
- [ ] Use regular optionals with proper unwrapping
- [ ] Only use IUO for IBOutlets or when guaranteed to be set

**Examples:**

❌ **Bad: Unnecessary IUO**
```swift
class UserViewModel {
    var authService: AuthService!  // ❌ Why IUO?
}
```

✅ **Good: Regular optional or non-optional**
```swift
class UserViewModel {
    let authService: AuthService  // ✅ Non-optional with DI

    init(authService: AuthService) {
        self.authService = authService
    }
}
```

✅ **Acceptable: IBOutlet**
```swift
class LoginViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!  // ✅ Acceptable for IB
}
```
