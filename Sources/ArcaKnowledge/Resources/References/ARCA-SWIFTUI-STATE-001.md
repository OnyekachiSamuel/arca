# Incorrect SwiftUI State Ownership

### @State for View-Local State

**Check for:**
- [ ] @State used only for view-owned state
- [ ] Private @State properties
- [ ] No @State for passed data

**Examples:**

❌ **Bad: @State for passed data**
```swift
struct UserDetailView: View {
    @State var user: User  // ❌ User should be passed as let

    var body: some View {
        // ...
    }
}
```

✅ **Good: @State for view-local state**
```swift
struct UserDetailView: View {
    let user: User  // ✅ Passed data as let

    @State private var isExpanded: Bool = false  // ✅ View-local state
    @State private var selectedTab: Tab = .profile

    var body: some View {
        VStack {
            Button(isExpanded ? "Collapse" : "Expand") {
                isExpanded.toggle()  // ✅ Modifying view-local state
            }
        }
    }
}
```

### @Binding for Two-Way Communication

**Check for:**
- [ ] @Binding used for child-to-parent communication
- [ ] Parent owns the state, child has @Binding
- [ ] No @Binding for read-only data

**Examples:**

❌ **Bad: Passing @State directly**
```swift
struct ParentView: View {
    @State private var text: String = ""

    var body: some View {
        ChildView(text: text)  // ❌ Child can't modify
    }
}

struct ChildView: View {
    let text: String
}
```

✅ **Good: Using @Binding for two-way communication**
```swift
struct ParentView: View {
    @State private var text: String = ""  // ✅ Parent owns state

    var body: some View {
        ChildView(text: $text)  // ✅ Pass binding with $
    }
}

struct ChildView: View {
    @Binding var text: String  // ✅ Child can read and write

    var body: some View {
        TextField("Enter text", text: $text)
    }
}
```

✅ **Good: Read-only without @Binding**
```swift
struct DisplayView: View {
    let text: String  // ✅ Read-only, no @Binding

    var body: some View {
        Text(text)
    }
}
```