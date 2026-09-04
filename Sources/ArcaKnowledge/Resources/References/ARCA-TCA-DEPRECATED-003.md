# Deprecated TaskResult Usage

## Asynchronous Work

**Check for:**

- [ ] Do not use deprecated `TaskResult`
- [ ] Use Swift `Result` instead

**Example:**

✅ **Good: Result for effect response**

```swift
@Reducer struct LoginFeature {
  @ObservableState struct State { ... }

  enum Action {
    case loginButtonTapped
    case response(Result<LoginResponse, any Error>)
  }

  @Dependency(APIClient.self) var apiClient

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .loginButtonTapped:
        return .run { send in
          await send(
            .response(
              Result {
                try await apiClient.login()
              }
            )
          )
        }
      }
    }
  }
}
```

**TCA version context:** 

This rule evaluates code against TCA 1.24.0. ARCA does not determine the dependency version from the analyzed source file.