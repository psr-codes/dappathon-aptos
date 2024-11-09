module MyModule::lottery {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use std::vector;
    use aptos_framework::timestamp;
    use std::option::{Self, Option};

    /// Custom errors
    const ENOT_ADMIN: u64 = 1;
    const ELOTTERY_ALREADY_INITIALIZED: u64 = 2;
    const ELOTTERY_NOT_ACTIVE: u64 = 3;
    const EINSUFFICIENT_BALANCE: u64 = 4;
    const ELOTTERY_ALREADY_DRAWN: u64 = 5;
    const ENO_PARTICIPANTS: u64 = 6;

    const ADMIN_ADDRESS: address = @0x791bb225d446fad68fb3aab4da12f8d58561f8291765c13b139e5921a68680e7;

    struct LotteryInfo has key {
        admin: address,
        ticket_price: u64,
        win_amount: u64,
        participants: vector<address>,
        is_active: bool,
        winner: Option<address>,
    }

    public entry fun initialize_lottery(
        admin: &signer,
        ticket_price: u64,
        win_amount: u64
    ) {
        let admin_address = signer::address_of(admin);
        assert!(admin_address == ADMIN_ADDRESS, ENOT_ADMIN);
        assert!(!exists<LotteryInfo>(admin_address), ELOTTERY_ALREADY_INITIALIZED);

        move_to(admin, LotteryInfo {
            admin: admin_address,
            ticket_price,
            win_amount,
            participants: vector::empty(),
            is_active: true,
            winner: option::none(),
        });
    }

    public entry fun buy_ticket(
        buyer: &signer
    ) acquires LotteryInfo {
        let lottery = borrow_global_mut<LotteryInfo>(ADMIN_ADDRESS);
        let buyer_addr = signer::address_of(buyer);
        
        // Verify lottery is active
        assert!(lottery.is_active, ELOTTERY_NOT_ACTIVE);
        
        // Verify buyer has sufficient balance
        assert!(
            coin::balance<AptosCoin>(buyer_addr) >= lottery.ticket_price,
            EINSUFFICIENT_BALANCE
        );
        
        // Transfer payment from buyer to admin
        coin::transfer<AptosCoin>(
            buyer,
            lottery.admin,
            lottery.ticket_price
        );
        
        // Add buyer to participants
        vector::push_back(&mut lottery.participants, buyer_addr);
    }

    public entry fun draw_winner(admin: &signer) acquires LotteryInfo {
        let admin_address = signer::address_of(admin);
        assert!(admin_address == ADMIN_ADDRESS, ENOT_ADMIN);
        
        let lottery = borrow_global_mut<LotteryInfo>(admin_address);
        assert!(lottery.is_active, ELOTTERY_NOT_ACTIVE);
        assert!(!vector::is_empty(&lottery.participants), ENO_PARTICIPANTS);
        assert!(option::is_none(&lottery.winner), ELOTTERY_ALREADY_DRAWN);

        let participants_length = vector::length(&lottery.participants) as u64;
        let current_timestamp = timestamp::now_microseconds();
        let winner_index = current_timestamp % participants_length;
        let winner = *vector::borrow(&lottery.participants, winner_index);

        // Transfer winning amount
        coin::transfer<AptosCoin>(admin, winner, lottery.win_amount);
        
        // Update lottery state
        lottery.winner = option::some(winner);
        lottery.is_active = false;
    }

    #[view]
    public fun get_lottery_info(): (u64, u64, bool, vector<address>, Option<address>) acquires LotteryInfo {
        let lottery = borrow_global<LotteryInfo>(ADMIN_ADDRESS);
        (
            lottery.ticket_price,
            lottery.win_amount,
            lottery.is_active,
            *&lottery.participants,
            *&lottery.winner
        )
    }

    #[view]
    public fun is_active(): bool acquires LotteryInfo {
        borrow_global<LotteryInfo>(ADMIN_ADDRESS).is_active
    }

    #[view]
    public fun get_ticket_price(): u64 acquires LotteryInfo {
        borrow_global<LotteryInfo>(ADMIN_ADDRESS).ticket_price
    }

    #[view]
    public fun get_participants(): vector<address> acquires LotteryInfo {
        *&borrow_global<LotteryInfo>(ADMIN_ADDRESS).participants
    }

    #[view]
    public fun get_winner(): Option<address> acquires LotteryInfo {
        *&borrow_global<LotteryInfo>(ADMIN_ADDRESS).winner
    }
}