# TCA Presentation API

## Presenting a Child Feature

**Check for:**

- [ ] Use `@Presents` for optional presentation state
- [ ] Use `PresentationAction` for presented child actions
- [ ] Compose the child with `ifLet`
- [ ] Do not use legacy `@PresentationState`
- [ ] Do not use legacy `sheet(store:)` or similar APIs

**Example:**

✅ **Good: @Presents child domain**

```swift
@Reducer struct Parent {
  @ObservableState struct State {
    @Presents var child: Child.State?
  }

  enum Action {
    case child(PresentationAction<Child.Action>)
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      // ...
    }
    .ifLet(\.$child, action: \.child) {
      Child()
    }
  }
}
```

✅ Good: Item-driven Store presentation

```swift
struct ParentView: View {
  @Bindable var store: StoreOf<Parent>

  var body: some View {
    // ...
    .sheet(
      item: $store.scope(state: \.child, action: \.child)
    ) { childStore in
      ChildView(store: childStore)
    }
  }
}
```

**TCA version context:** 

This rule evaluates code against TCA 1.24.0. ARCA does not determine the dependency version from the analyzed source file.