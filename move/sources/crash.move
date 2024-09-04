module crash::game {
    use std::option::Option;
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin;
    use aptos_framework::coin;
    use std::signer;
    use aptos_framework::object::{Self, ObjectCore};
    use aptos_std::table::{Self, Table};
    use std::option;

    const E_NOT_ENOUGH_FUNDS: u64 = 0;
    const E_MULTIPLIER_TOO_LOW: u64 = 1;
    const E_MULTIPLIER_TOO_HIGH: u64 = 2;
    const E_ROUND_NOT_FINISHED: u64 = 3;

    const E_ONLY_ADMIN: u64 = 3;


    const ROUND_HOLDER_SEED: vector<u8> = b"ROUND_HOLDER";

    struct RoundHolder has key {
        rounds: Table<u64, Round>
    }

    // NOTE: admin could just be @crash?
    struct Config has key {
        admin: address,
    }

    const ROUND_OPEN: u64 = 0;
    const ROUND_ONGOING: u64 = 1;
    const ROUND_ENDED: u64 = 2;

    struct Round has store {
        status: u64,
        userStates: Table<address, PlayerRoundState>
    }

    struct PlayerRoundState has store {
        amount: u64,
        claimed_multiplier: Option<u64>
    }

    /// A valid multiplier is between 1 and 10 but we need support for 2 decimals, so we want something between 100 and 1_000
    fun is_valid_multiplier(multiplier: u64) {
        assert!(multiplier >= 100, E_MULTIPLIER_TOO_LOW);
        assert!(multiplier <= 1000, E_MULTIPLIER_TOO_HIGH);
    }

    fun ensure_is_admin(caller: address) acquires Config {
        let config = borrow_global<Config>(@crash);
        assert!(is_admin(config, caller), E_ONLY_ADMIN);
    }

    #[event]
    struct RoundStartEvent has store, drop {}


    #[event]
    struct RoundEndEvent has store, drop {}


    public fun init_module(admin: &signer) {}


    public entry fun start_next_round(user: &signer) {}

    public entry fun end_round(user: &signer) {}


    public entry fun bet_on_next_round(user: &signer, amount: u64) {
        // TODO: check if round is properly setup
        let user_addr = signer::address_of(user);
        let user_balance = coin::balance<aptos_coin::AptosCoin>(user_addr);
        assert!(user_balance >= amount, E_NOT_ENOUGH_FUNDS);

        aptos_account::transfer(user, @crash, amount);

        // TODO: register multiplier and user's play
    }

    public entry fun claim_multiplier(user: &signer, multiplier: u64) {
        is_valid_multiplier(multiplier);
        // TODO: check if user is part of the current round

        // TODO: set multiplier in state
    }

    /// Claim my rewards iterates over all the rounds a user is a part of and computes amount * claimed_multiplier
    public entry fun claim_my_rewards(user: &signer) {}


    // Utils
    fun reward_for(round_id: u64, user: address): u64 acquires RoundHolder {
        let roundHolder = borrow_global<RoundHolder>(@crash);
        let round = table::borrow(&roundHolder.rounds, round_id);
        assert!(round.status == ROUND_ENDED, E_ROUND_NOT_FINISHED);

        let reward = 0;
        if (table::contains(&round.userStates, user)) {
            let playerState = table::borrow(&round.userStates, user);

            if (option::is_some(&playerState.claimed_multiplier)) {
                let multiplier = option::extract(&mut playerState.claimed_multiplier);
                reward = multiplier * playerState.amount;
            }
        };

        reward
    }

    fun get_current_round() {}

    fun get_next_round() {}


    /// Check if sender is admin or owner of the object when package is published to object
    fun is_admin(config: &Config, sender: address): bool {
        if (sender == config.admin) {
            true
        } else {
            if (object::is_object(@crash)) {
                let obj = object::address_to_object<ObjectCore>(@crash);
                object::is_owner(obj, sender)
            } else {
                false
            }
        }
    }


    // Views
    #[view]
    public fun get_round_result() {}

    #[view]
    public fun get_user_rewards(user: address) {}
}