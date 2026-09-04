# Bypassing a Controlled TCA Dependency

## Controlling Feature Dependencies

**Check for:**

- [ ] Declare controllable dependencies directly in the reducer
- [ ] Use declared TCA dependencies instead of uncontrolled alternatives
- [ ] Prefer controlled dependencies for nondeterministic values and external operations

**Example:**

✅ **Good: Controlled date dependency**

```swift
@Reducer struct WhatTimeIsIt {
  @ObservableState struct State {
    var message = ""
  }

  enum Action {
    case questionButtonTapped
  }

  @Dependency(\.date.now) var now

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .questionButtonTapped:
        state.message = "It's \(now)"
        return .none
      }
    }
  }
}
```