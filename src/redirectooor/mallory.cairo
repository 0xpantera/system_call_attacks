#[starknet::interface]
pub trait IMallory<TState> {
    fn who_is_calling(self: @TState, new_class_hash: felt252);
}

#[starknet::contract]
mod Mallory {
    use starknet::ClassHash;
    use starknet::syscalls::replace_class_syscall;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl IMalloryImpl of super::IMallory<ContractState> {
        fn who_is_calling(self: @ContractState, new_class_hash: felt252) {
            let class_hash: ClassHash = new_class_hash.try_into().unwrap();
            replace_class_syscall(class_hash).unwrap();
        }
    }
}