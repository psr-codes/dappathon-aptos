module MyModule::Lottery {
    use std::signer;
    use aptos_framework::coin::{Self};
    use aptos_framework::aptos_coin::AptosCoin;
    use std::vector;
    use aptos_framework::timestamp;

    const ELOTTERY_NOT_ACTIVE: u64 = 1;
    const ENOT_ADMIN: u64 = 2;
    const ENO_PARTICIPANTS: u64 = 3;
    const EINVALID_AMOUNT: u64 = 4;

    struct LotteryInfo has key {
        admin: address,
        ticket_price: u64,
        win_amount: u64,
        participants: vector<address>,
        is_active: bool,
    }

    public entry fun initialize_lottery(
        admin: &signer,
        ticket_price: u64,
        win_amount: u64
    ) {
        assert!(!exists<LotteryInfo>(signer::address_of(admin)), EINVALID_AMOUNT);

        let lottery = LotteryInfo {
            admin: signer::address_of(admin),
            ticket_price,
            win_amount,
            participants: vector::empty<address>(),
            is_active: true,
        };
        move_to(admin, lottery);
    }

    public entry fun buy_ticket(
        buyer: &signer,
        admin_addr: address
    ) acquires LotteryInfo {
        let lottery = borrow_global_mut<LotteryInfo>(admin_addr);
        assert!(lottery.is_active, ELOTTERY_NOT_ACTIVE);

        let buyer_addr = signer::address_of(buyer);
        coin::transfer<AptosCoin>(buyer, admin_addr, lottery.ticket_price);
        vector::push_back(&mut lottery.participants, buyer_addr);
    }

    public entry fun draw_winner(
        admin: &signer
    ) acquires LotteryInfo {
        let admin_addr = signer::address_of(admin);
        let lottery = borrow_global_mut<LotteryInfo>(admin_addr);

        assert!(admin_addr == lottery.admin, ENOT_ADMIN);
        assert!(lottery.is_active, ELOTTERY_NOT_ACTIVE);
        assert!(!vector::is_empty(&lottery.participants), ENO_PARTICIPANTS);

        let participants_length = vector::length(&lottery.participants) as u64;
        let current_timestamp = timestamp::now_microseconds();
        let winner_index = current_timestamp % participants_length;
        let winner = *vector::borrow(&lottery.participants, winner_index);

        coin::transfer<AptosCoin>(admin, winner, lottery.win_amount);
        lottery.is_active = false;
    }

    #[view]
    public fun get_lottery_info(admin_addr: address): (u64, u64, bool, vector<address>) acquires LotteryInfo {
        let lottery = borrow_global<LotteryInfo>(admin_addr);
        (
            lottery.ticket_price,
            lottery.win_amount,
            lottery.is_active,
            *&lottery.participants
        )
    }

    #[view]
    public fun is_active(admin_addr: address): bool acquires LotteryInfo {
        borrow_global<LotteryInfo>(admin_addr).is_active
    }

    #[view]
    public fun get_ticket_price(admin_addr: address): u64 acquires LotteryInfo {
        borrow_global<LotteryInfo>(admin_addr).ticket_price
    }

    #[view]
    public fun get_participants(admin_addr: address): vector<address> acquires LotteryInfo {
        *&borrow_global<LotteryInfo>(admin_addr).participants
    }
}
