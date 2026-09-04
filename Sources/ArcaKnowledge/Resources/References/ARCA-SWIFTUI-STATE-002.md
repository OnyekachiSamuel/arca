# Incompatible Observation Mechanisms

### @Observable (iOS 17+, macOS 14+)

**Check for:**
- [ ] @Observable used for view models and observable objects
- [ ] No mixing @Observable with @StateObject/@ObservedObject
- [ ] Proper state isolation

**Examples:**

❌ **Bad: Using old ObservableObject pattern**
```swift
class LoginViewModel: ObservableObject {  // ❌ Old pattern (iOS 17+)
    @Published var email: String = ""
    @Published var isLoading: Bool = false
}

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()  // ❌ Old pattern
}
```

✅ **Good: Modern @Observable pattern**
```swift
@Observable
final class LoginViewModel {  // ✅ Modern pattern (iOS 17+)
    var email: String = ""
    var isLoading: Bool = false

    func login() async {
        isLoading = true
        // Login logic
        isLoading = false
    }
}

struct LoginView: View {
    let viewModel: LoginViewModel  // ✅ No property wrapper needed

    var body: some View {
        // Automatically observes viewModel changes
    }
}
```

✅ **Good: @Observable with MainActor**
```swift
@MainActor
@Observable
final class UserListViewModel {  // ✅ MainActor + Observable
    var users: [User] = []
    var isLoading: Bool = false

    func fetchUsers() async {
        // Always runs on main actor
    }
}
```

### Common Mistakes

**Check for:**
- [ ] No @StateObject with @Observable classes
- [ ] No @Published with @Observable classes
- [ ] No @State for objects (use @Observable instead)
- [ ] No @Binding for read-only data

**Examples:**

❌ **Bad: @StateObject with @Observable**
```swift
@Observable
final class ViewModel { }

struct MyView: View {
    @StateObject private var viewModel = ViewModel()  // ❌ Don't mix
}
```

✅ **Good: No wrapper with @Observable**
```swift
@Observable
final class ViewModel { }

struct MyView: View {
    let viewModel = ViewModel()  // ✅ No wrapper needed (iOS 17+)
}
```

❌ **Bad: @Published with @Observable**
```swift
@Observable
final class ViewModel {
    @Published var text: String = ""  // ❌ Don't mix
}
```

✅ **Good: Regular property with @Observable**
```swift
@Observable
final class ViewModel {
    var text: String = ""  // ✅ Automatically observable
}
```