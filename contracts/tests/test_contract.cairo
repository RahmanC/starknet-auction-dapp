use starknet::ContractAddress;

use snforge_std::{
    declare, 
    ContractClassTrait, 
    DeclareResultTrait, 
    start_cheat_caller_address, 
    stop_cheat_caller_address
};

#[starknet::interface]
pub trait IAuctionTest<TContractState> {
    fn initialize(ref self: TContractState, duration: u64);
    fn place_bid(ref self: TContractState, bid_amount: u64);
    fn end_auction(ref self: TContractState);
    fn get_highest_bidder(self: @TContractState) -> ContractAddress;
    fn get_highest_bid(self: @TContractState) -> u64;
    fn get_auction_end(self: @TContractState) -> u64;
}

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_initialize() {
    let contract_address = deploy_contract("AuctionContract");
    let auction_contract = IAuctionTestDispatcher { contract_address };

    let duration: u64 = 3600; 
    auction_contract.initialize(duration);

    let auction_end = auction_contract.get_auction_end();
    let current_timestamp = starknet::get_block_timestamp();

    assert(auction_end == current_timestamp + duration, 'Incorrect auction end time');
    assert(auction_contract.get_highest_bid() == 0, 'Initial bid should be zero');
}

#[test]
fn test_place_bid() {
    let contract_address = deploy_contract("AuctionContract");
    let auction_contract = IAuctionTestDispatcher { contract_address };

    // Initialize auction
    let duration: u64 = 3600; 
    auction_contract.initialize(duration);

    let bidder1: ContractAddress = starknet::contract_address_const::<0x123450011>();
    let bidder2: ContractAddress = starknet::contract_address_const::<0x123450022>();

    // First bid
    start_cheat_caller_address(contract_address, bidder1);
    auction_contract.place_bid(100);
    stop_cheat_caller_address(contract_address);

    assert(auction_contract.get_highest_bid() == 100, 'First bid failed');
    assert(auction_contract.get_highest_bidder() == bidder1, 'Incorrect highest bidder');

    // Higher bid from another bidder
    start_cheat_caller_address(contract_address, bidder2);
    auction_contract.place_bid(200);
    stop_cheat_caller_address(contract_address);

    assert(auction_contract.get_highest_bid() == 200, 'Second bid failed');
    assert(auction_contract.get_highest_bidder() == bidder2, 'Incorrect highest bidder');
}

#[test]
#[should_panic(expected: ('Bid too low', ))]
fn test_place_bid_too_low() {
    let contract_address = deploy_contract("AuctionContract");
    let auction_contract = IAuctionTestDispatcher { contract_address };

    // Initialize auction
    let duration: u64 = 3600; 
    auction_contract.initialize(duration);

    // First bid
    let bidder1: ContractAddress = starknet::contract_address_const::<0x123450011>();
    start_cheat_caller_address(contract_address, bidder1);
    auction_contract.place_bid(100);
    stop_cheat_caller_address(contract_address);

    // Attempt lower bid 
    let bidder2: ContractAddress = starknet::contract_address_const::<0x123450022>();
    start_cheat_caller_address(contract_address, bidder2);
    auction_contract.place_bid(50);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Auction ended', ))]
fn test_place_bid_after_auction_end() {
    let contract_address = deploy_contract("AuctionContract");
    let auction_contract = IAuctionTestDispatcher { contract_address };

    let duration: u64 = 10; // 10 seconds
    let init_timestamp = starknet::get_block_timestamp();
    auction_contract.initialize(duration);

    // Simulate time passing beyond auction end
    let current_timestamp = init_timestamp + duration + 1;
    
    // Attempt to place bid after auction end 
    let bidder: ContractAddress = starknet::contract_address_const::<0x123450011>();
    start_cheat_caller_address(contract_address, bidder);
    auction_contract.place_bid(100);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_end_auction() {
    let contract_address = deploy_contract("AuctionContract");
    let auction_contract = IAuctionTestDispatcher { contract_address };

    let duration: u64 = 10; 
    let init_timestamp = starknet::get_block_timestamp();
    auction_contract.initialize(duration);

    let bidder: ContractAddress = starknet::contract_address_const::<0x123450011>();
    start_cheat_caller_address(contract_address, bidder);
    auction_contract.place_bid(100);
    stop_cheat_caller_address(contract_address);

    // Simulate time passing beyond auction end
    let current_timestamp = init_timestamp + duration + 1;

    auction_contract.end_auction();

    assert(auction_contract.get_highest_bidder() == bidder, 'Incorrect auction winner');
    assert(auction_contract.get_highest_bid() == 100, 'Incorrect winning bid');
}

#[test]
#[should_panic(expected: ('Auction still ongoing', ))]
fn test_end_auction_too_early() {
    let contract_address = deploy_contract("AuctionContract");
    let auction_contract = IAuctionTestDispatcher { contract_address };

    let duration: u64 = 3600; // 1 hour
    auction_contract.initialize(duration);

    // Attempt to end auction before it's time 
    auction_contract.end_auction();
}