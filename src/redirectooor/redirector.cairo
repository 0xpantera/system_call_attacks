use starknet::ClassHash;

#[starknet::interface]
pub trait IRedirector<TContractState> {
    fn redirect_the_call(
        ref self: TContractState, 
        class_hash: ClassHash, 
        args: Span<felt252>
    ) -> Span<felt252>;
}

#[starknet::contract]
mod Redirector {
    use starknet::{ClassHash, SyscallResultTrait};
    use starknet::syscalls::{library_call_syscall};

    const WHO_IS_CALLING_SELECTOR: felt252 = selector!("who_is_calling");
    
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl IRedirectorImpl of super::IRedirector<ContractState> {
        
        // Redirect the call to the library
        // Takes classhash and args as input
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
    }
}
