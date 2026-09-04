# Unnecessary CombineReducers Wrapper

## Reducer Composition

**Check for:**

- [ ] Use of `CombineReducers` when multiple reducers must be grouped before a modifier
- [ ] Do not wrap reducers in `CombineReducers` when no modifier needs the combined reducer

**Example:**

✅ **Good: CombineReducers used before ifLet**

```swift
var body: some Reducer<State, Action> {
  CombineReducers {
    Scope(state: \.child1, action: \.child1) {
      Child1()
    }

    Scope(state: \.child2, action: \.child2) {
      Child2()
    }
  }
  .ifLet(\.$child3, action: \.child3) {
    Child3()
  }
}
```