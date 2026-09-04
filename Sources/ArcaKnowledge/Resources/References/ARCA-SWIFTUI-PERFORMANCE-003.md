# Excessive Observable State Dependency

### Read Only What You Display

**Check for:**
- [ ] Views read only the properties they actually display (not entire `@Observable` objects passed unnecessarily)
- [ ] Subviews receive minimal data needed (IDs or value types when possible, not full observable models)
- [ ] `@Observable` objects not passed to descendants that don't observe them

**Examples:**

❌ **Bad: Passing entire observable to unrelated subview**
```swift
@Observable
final class FeedViewModel {
    var posts: [Post] = []
    var isLoading: Bool = false
    var currentUser: User = .placeholder
    var unreadCount: Int = 0
    // ... many more properties
}

struct FeedView: View {
    let viewModel: FeedViewModel

    var body: some View {
        List(viewModel.posts) { post in
            PostRow(viewModel: viewModel, post: post)  // ❌ Passes entire ViewModel
        }
    }
}

struct PostRow: View {
    let viewModel: FeedViewModel  // ❌ Observes ALL viewModel properties, re-renders on any change
    let post: Post

    var body: some View {
        Text(post.title)  // Only uses post, but re-renders on isLoading, unreadCount changes
    }
}
```

✅ **Good: Pass only what the subview needs**
```swift
struct FeedView: View {
    let viewModel: FeedViewModel

    var body: some View {
        List(viewModel.posts) { post in
            PostRow(post: post)  // ✅ Pass only the value, not the entire observable
        }
    }
}

struct PostRow: View {
    let post: Post  // ✅ Only observes/depends on this post

    var body: some View {
        Text(post.title)
    }
}
```