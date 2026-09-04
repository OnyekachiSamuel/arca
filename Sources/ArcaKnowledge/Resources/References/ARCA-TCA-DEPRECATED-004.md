# TCA Binding API

## Bindable Feature State

**Check for:**

- [ ] Use observable state for bindable feature state
- [ ] Keep `BindableAction` for binding actions where needed
- [ ] Include `BindingReducer()` in the reducer
- [ ] Derive bindings from a bindable `Store`
- [ ] Do not use legacy binding-state wrappers

**Example:**

✅ **Good: BindingReducer with bindable Store**

```swift
@Reducer struct Counter {
  @ObservableState struct State {
    var count = 0
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
  }
}
```

**TCA version context:** 

This rule evaluates code against TCA 1.24.0. ARCA does not determine the dependency version from the analyzed source file.