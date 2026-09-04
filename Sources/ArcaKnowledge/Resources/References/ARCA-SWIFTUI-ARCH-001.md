# Business Logic in SwiftUI View

### MVVM (Model-View-ViewModel) Overview

**Structure:**
- **View**: SwiftUI views (presentation only)
- **ViewModel**: Business logic and state management
- **Model**: Data structures and domain logic

**Responsibilities:**

| Layer | Responsibilities | Does NOT Do |
|-------|-----------------|-------------|
| **View** | - Display data<br>- User interactions<br>- UI layout | - Business logic<br>- Data fetching<br>- Validation |
| **ViewModel** | - Business logic<br>- State management<br>- Data transformation<br>- Validation | - UI code<br>- View hierarchy<br>- Direct database/network |
| **Model** | - Data structures<br>- Domain logic<br>- Business rules | - UI concerns<br>- State management |

### 1.2 Implementation Pattern

**Check for:**
- [ ] Views only contain presentation logic
- [ ] ViewModels contain all business logic
- [ ] Clear separation between View and ViewModel
- [ ] Dependency injection for services

**Examples:**

❌ **Bad: Business logic in view**
```swift
struct UserListView: View {
    @State private var users: [User] = []
    @State private var isLoading = false

    var body: some View {
        List(users) { user in
            UserRow(user: user)
        }
        .onAppear {
            loadUsers()  // ❌ Business logic in view
        }
    }

    private func loadUsers() {
        isLoading = true
        Task {
            // ❌ Network call directly in view
            let response = try await URLSession.shared.data(from: usersURL)
            users = try JSONDecoder().decode([User].self, from: response.0)
            isLoading = false
        }
    }
}
```

✅ **Good: MVVM structure**
```swift
// Model
struct User: Identifiable, Codable {
    let id: UUID
    let name: String
    let email: String
}

// ViewModel
@MainActor
@Observable
final class UserListViewModel {
    private let userRepository: UserRepository

    private(set) var users: [User] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func loadUsers() async {
        isLoading = true
        error = nil

        do {
            users = try await userRepository.fetchUsers()
        } catch {
            self.error = error
        }

        isLoading = false
    }
}

// View
struct UserListView: View {
    let viewModel: UserListViewModel

    var body: some View {
        List(viewModel.users) { user in
            UserRow(user: user)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.loadUsers()  // ✅ View triggers, ViewModel handles
        }
    }
}
```