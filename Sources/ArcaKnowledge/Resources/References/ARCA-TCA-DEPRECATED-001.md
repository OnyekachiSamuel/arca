# Reducer API Usage

## Building a TCA Feature

**Check for:**

- [ ] Do not use the legacy `reduce(into:)` API
- [ ] Define feature logic through `body` and `Reduce`

**Example:**

✅ **Good: Reducer body with Reduce**

```swift
@Reducer struct Counter {
  @ObservableState struct State {
    var count = 0
  }

  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:
        state.count -= 1
        return .none

      case .incrementButtonTapped:
        state.count += 1
        return .none
      }
    }
  }
}
```

**TCA version context:** 

This rule evaluates code against TCA 1.25.0. ARCA does not determine the dependency version from the analyzed source file.