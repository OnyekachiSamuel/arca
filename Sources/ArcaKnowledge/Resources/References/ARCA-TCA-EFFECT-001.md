# Missing Cancellation Management for Cancellable Effect

## Explicit Effect Cancellation

**Check for:**

- [ ] Give explicitly cancellable work a cancellation identifier
- [ ] Attach the identifier to the effect with `.cancellable(id:)`
- [ ] Cancel the effect with the matching `.cancel(id:)`

**Example:**

```swift
enum CancelID {
  case apiRequest
}
```

✅ Good: Cancellable effect

```swift
case .fetchButtonTapped:
  return .run { send in
    // ...
  }
  .cancellable(id: CancelID.apiRequest)
```
✅ Good: Matching cancellation

```swift
case .cancelButtonTapped:
  return .cancel(id: CancelID.apiRequest)
```

