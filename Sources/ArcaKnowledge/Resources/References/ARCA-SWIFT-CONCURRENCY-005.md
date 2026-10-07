# Unsafe Actor State Assumption After Suspension

### Actor Reentrancy

**Check for:**
- [ ] Actor state is established or read before `await`
- [ ] Execution suspends
- [ ] Code relies on the earlier state without validation

**Do not flag:**
- [ ] State-dependent work completed before suspension
- [ ] Post-suspension state is revalidated
- [ ] An actor method merely contains `await`

**Examples:**

❌ **Bad: State is assumed unchanged after suspension**
```swift
actor BankAccount {
    var balance: Double
    
    func deposit(amount: Double) async {
        balance += amount
        
        // ⚠️ Actor unlocked during await
        await logActivity("Deposited \(amount)")
        
        // ⚠️ Balance may have changed!
        print("Balance: \(balance)")
    }
}
```

✅ **Good: Complete state-dependent work before suspension**
```swift
func deposit(amount: Double) async {
    balance += amount
    print("Balance: \(balance)") // Before suspension
    
    await logActivity("Deposited \(amount)")
}
```
