# System Call Attacks in Starknet

This repository demonstrates critical vulnerabilities related to Starknet system calls and how they can be exploited.

## Overview

The project focuses on two main categories of system call vulnerabilities:

1. **Library Call Exploits (`redirectooor`)** - Demonstrates how attackers can exploit the `library_call_syscall` to replace class implementations.
2. **Contract Call Exploits (`hook_me_up`)** - Shows how improper use of `call_contract_syscall` can lead to funds being stolen.

## Vulnerabilities Explained

### 1. Redirectooor - Library Call Vulnerability

The redirector contract provides functionality to call a specified class hash using `library_call_syscall`. However, if improperly implemented, this can lead to a critical vulnerability:

```cairo
fn redirect_the_call(
    ref self: ContractState,
    class_hash: ClassHash,
    args: Span<felt252>
) -> Span<felt252>
{
    return library_call_syscall(
        class_hash,
        WHO_IS_CALLING_SELECTOR,
        args
    ).unwrap_syscall();
}
```

**The Attack:**
- The attacker calls the redirector with a malicious contract class hash (Mallory)
- Mallory contains code to replace the class implementation using `replace_class_syscall`
- This permanently breaks the redirector by pointing it to an incompatible implementation

This attack demonstrates why contracts should carefully validate what class hashes they call with `library_call_syscall`.

### 2. Hook Me Up - Contract Call Vulnerability

The SoyBank contract allows deposits to other users with a "hook" mechanism:

```cairo
fn deposit(
    ref self: ContractState,
    amount: u256,
    user: ContractAddress,
    hook_selector: felt252,
    hook_data: Span<felt252>,
) {
    // Update receiver balance...

    // If the receiver is not the caller, it's a gift
    if user != caller {
        let mut result = call_contract_syscall(user, hook_selector, hook_data)
            .unwrap_syscall();
        let accepted: bool = Serde::<bool>::deserialize(ref result).unwrap();
        assert(accepted, 'The present was not accepted');
    }

    // Transfer funds...
}
```

**The Attack:**
- The attacker provides the ERC20 token address as the `user` parameter
- The attacker specifies `approve` as the hook selector
- The hook data contains parameters to make the token approve a large amount to the attacker
- The bank contract unknowingly calls `approve` on the token
- The attacker can then transfer the approved tokens out of the bank

This shows how unchecked use of `call_contract_syscall` with user-controlled parameters can lead to catastrophic results.

## Lessons Learned

1. **Never trust user input for system calls**: Always validate addresses, selectors, and data before using them in system calls.

2. **Use patterns that limit privileges**: Apply the principle of least privilege to system calls.

3. **Validate return values**: Always check what a system call returns before proceeding.

4. **Be cautious with class hash replacements**: The `replace_class_syscall` should be used with extreme caution and proper access control.

## Running the Tests

The project includes tests that demonstrate these vulnerabilities:

```bash
scarb test
```

These tests show how the attacks are executed and their consequences.
