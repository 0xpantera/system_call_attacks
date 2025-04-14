use starknet::{ContractAddress, ClassHash};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, 
    start_cheat_caller_address, stop_cheat_caller_address, 
    start_cheat_block_timestamp
};

use system_call_attacks::redirectooor::identity::{
    IIdentityContractDispatcher, IIdentityContractDispatcherTrait
};
use system_call_attacks::redirectooor::redirector::{
    IRedirectorDispatcher, IRedirectorDispatcherTrait
};

fn deploy_redirector() -> (ContractAddress, IRedirectorDispatcher) {
    let contract_class = declare("Redirector").unwrap().contract_class();
    let (address, _) = contract_class.deploy(@array![]).unwrap();
    return (address, IRedirectorDispatcher { contract_address: address });
}

#[test]
#[should_panic]
fn test_redirector_attack() {
    // Create Alice & Attacker
    let alice: ContractAddress = 1.try_into().unwrap();
    let _attacker: ContractAddress = 2.try_into().unwrap();

    // Deploying the contracts
    let (redirector_address, redirector_dispatcher) = deploy_redirector();

    // Identity class
    let identity_class_hash = *(declare("IdentityContract").unwrap().contract_class().class_hash);

    // Checking the redirector
    start_cheat_caller_address(redirector_address, alice);
    // Use * to get the value
    let result = *redirector_dispatcher.redirect_the_call(
        identity_class_hash, 
        array![].span()
    )[0]; 
    // Clone because of borrow checker
    let caller = result.clone();
    assert(caller == alice.into(), 'The caller is not Alice');
    stop_cheat_caller_address(redirector_address);

    // ATTACK START //
    // TODO: Break the redirector so it will no longer work

    // ATTACK END //

    // Call again to ensure redirector doesn't work (should panic)
    let _result = *redirector_dispatcher.redirect_the_call(
        identity_class_hash, 
        array![].span()
    )[0];
}

