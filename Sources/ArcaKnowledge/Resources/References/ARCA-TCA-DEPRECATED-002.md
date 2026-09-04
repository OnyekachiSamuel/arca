# TCA View Observation API

## Interacting with a Feature from SwiftUI

**Check for:**

- [ ] Do not use legacy `ViewStore`
- [ ] Do not use legacy `WithViewStore`
- [ ] Read observable feature state directly from `Store`
- [ ] Send actions directly through `Store`

**Example:**

✅ **Good: Direct Store observation**

```swift
struct CounterView: View {
  let store: StoreOf<Counter>

  var body: some View {
    HStack {
      Button {
        store.send(.decrementButtonTapped)
      } label: {
        Image(systemName: "minus")
      }

      Text("\(store.count)")

      Button {
        store.send(.incrementButtonTapped)
      } label: {
        Image(systemName: "plus")
      }
    }
  }
}
```

**TCA version context:** 

This rule evaluates code against TCA 1.24.0. ARCA does not determine the dependency version from the analyzed source file.