use starknet::ContractAddress;

#[starknet::interface]
pub trait ISoyBank<TContractState> {
    fn deposit(
        ref self: TContractState,
        amount: u256,
        user: ContractAddress,
        hook_selector: felt252,
        hook_data: Span<felt252>,
    );
    fn withdraw(ref self: TContractState, amount: u256);
    fn get_balance(self: @TContractState) -> u256;
}

#[starknet::contract]
mod SoyBank {
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResultTrait, get_caller_address, get_contract_address};

    #[storage]
    struct Storage {
        balances: Map<ContractAddress, u256>, // Balances of the accounts
        currency: IERC20Dispatcher, // The token to be used as currency
        hooks: Map<ContractAddress, ContractAddress> // Hooks for the customers
    }

    #[constructor]
    fn constructor(ref self: ContractState, currency: ContractAddress) {
        self.currency.write(IERC20Dispatcher { contract_address: currency });
    }

    #[abi(embed_v0)]
    impl ISoyBankImpl of super::ISoyBank<ContractState> {
        // Deposit into the bank.
        // Users can deposit currency for themselves or for other users as a gift.
        // In case it's a gift they need to provide the hook_selector and hook_data for the
        // destination account
        fn deposit(
            ref self: ContractState,
            amount: u256,
            user: ContractAddress,
            hook_selector: felt252,
            hook_data: Span<felt252>,
        ) {
            // Update the receiver balance
            let caller = get_caller_address();
            self.balances.write(user, self.balances.read(user) + amount);

            // If the receiver is not the caller, it's a gift for another account.
            // We want to make sure the destination account is willing to receive the gift
            if user != caller {
                let mut result = call_contract_syscall(user, hook_selector, hook_data)
                    .unwrap_syscall();
                let accepted: bool = Serde::<bool>::deserialize(ref result).unwrap();
                assert(accepted, 'The present was not accepted');
            }

            self.currency.read().transfer_from(caller, get_contract_address(), amount);
        }

        // Withdraw from the bank
        fn withdraw(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            let balance = self.balances.read(caller);

            assert(balance >= amount, 'Not enough balance');

            self.balances.write(caller, balance - amount);
            self.currency.read().transfer(caller, amount);
        }

        // Return the balance of the caller
        fn get_balance(self: @ContractState) -> u256 {
            let caller = get_caller_address();
            self.balances.read(caller)
        }
    }
}
