module crash::game {
    use std::option::Option;
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin;
    use aptos_framework::coin;
    use std::signer;
    use aptos_framework::event;
    use aptos_framework::object::{Self, ObjectCore};
    use aptos_std::table::{Self, Table};
    use std::option;
    use aptos_framework::account::{SignerCapability, create_signer_with_capability, create_resource_account};

    const E_MULTIPLIER_TOO_LOW: u64 = 1;
    const E_MULTIPLIER_TOO_HIGH: u64 = 2;
    const E_ROUND_NOT_FINISHED: u64 = 3;
    const E_ONLY_ADMIN: u64 = 4;
    const E_UNIMPLEMENTED: u64 = 5;
    const E_NOT_ENOUGH_FUNDS: u64 = 6;
    const E_NOT_REGISTERED: u64 = 7;
    const E_ALREADY_CLAIMED_MULTIPLIER: u64 = 8;
    const E_ALREADY_CLAIMED_REWARDS: u64 = 9;


    const ROUND_HOLDER_SEED: vector<u8> = b"ROUND_HOLDER";

    struct RoundHolder has key {
        rounds: Table<u64, Round>,

        // easier access for following rounds
        current: u64,
    }

    // NOTE: admin could just be @crash?
    struct Config has key {
        admin: address,
        signer_cap: SignerCapability
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
        claimed_multiplier: Option<u64>,
        claimed: bool,
    }

    const MIN_MULTIPLIER: u64 = 100;
    const MAX_MULTIPLIER: u64 = 1_000;

    /// A valid multiplier is between 1 and 10 but we need support for 2 decimals, so we want something between 100 and 1_000
    fun is_valid_multiplier(multiplier: u64) {
        assert!(multiplier >= MIN_MULTIPLIER, E_MULTIPLIER_TOO_LOW);
        assert!(multiplier <= MAX_MULTIPLIER, E_MULTIPLIER_TOO_HIGH);
    }


    fun is_registered_in_round_v0(user: address, id: u64) acquires RoundHolder {
        let round_holder = borrow_global<RoundHolder>(@crash);
        let round = table::borrow(&round_holder.rounds, id);

        assert!(table::contains(&round.userStates, user), E_NOT_REGISTERED);
    }

    fun is_registered_in_round(user: address, round: &Round) {
        assert!(table::contains(&round.userStates, user), E_NOT_REGISTERED);
    }

    fun ensure_is_admin(caller: address) acquires Config {
        let config = borrow_global<Config>(@crash);
        assert!(is_admin(config, caller), E_ONLY_ADMIN);
    }

    #[event]
    struct RoundStartEvent has store, drop {
        id: u64,
        multiplier: u64
    }

    #[event]
    struct RoundOpenEvent has store, drop {
        id: u64,
    }

    #[event]
    struct UserBetEvent has store, drop {
        round_id: u64,
        user: address,
        amount: u64
    }

    #[event]
    struct ClaimMultiplierEvent has store, drop {
        user: address,
        multiplier: u64
    }

    #[event]
    struct ClaimRewardsEvent has store, drop {
        user: address,
        rewards: u64,
        round: u64
    }

    // FIXME: Remove as unusued
    // NOTE: leaving it here so I don't have to recreate an account to upload code.
    #[event]
    struct RoundEndEvent has store, drop {}

    #[event]
    struct RoundCloseEvent has store, drop {
        id: u64,
    }

    const RESOURCE_SEED: vector<u8> = b"RESOURCE";

    fun init_module(admin: &signer) {
        let (_, signer_cap) = create_resource_account(admin, RESOURCE_SEED);

        //let signer_cap = resource_account::retrieve_resource_account_cap(admin, @crash);

        let config = Config {
            admin: signer::address_of(admin),
            signer_cap,
        };

        let round_holder = RoundHolder {
            rounds: table::new<u64, Round>(),
            current: 1
        };

        move_to(admin, config);
        move_to(admin, round_holder);
    }

    #[randomness]
    entry fun start_next_round(user: &signer) acquires RoundHolder, Config {
        ensure_is_admin(signer::address_of(user));
        let round_multiplier = roll_multiplier();
        let round_holder = borrow_global_mut<RoundHolder>(@crash);


        let current_round_id = round_holder.current;

        if (!table::contains(&round_holder.rounds, current_round_id)) {
            table::add(
                &mut round_holder.rounds,
                current_round_id,
                Round { status: ROUND_OPEN, userStates: table::new<address, PlayerRoundState>() }
            );
        };
        let current_round = table::borrow_mut(&mut round_holder.rounds, current_round_id);
        current_round.status = ROUND_ONGOING;


        event::emit(RoundStartEvent {
            multiplier: round_multiplier,
            id: current_round_id
        });

        round_holder.current = current_round_id + 1;

        table::add(
            &mut round_holder.rounds,
            round_holder.current,
            Round { status: ROUND_OPEN, userStates: table::new<address, PlayerRoundState>() }
        );
    }

    public entry fun end_round(user: &signer) acquires Config, RoundHolder {
        ensure_is_admin(signer::address_of(user));

        let round_holder = borrow_global_mut<RoundHolder>(@crash);

        let round_id_to_close = round_holder.current - 1;
        let round_to_close = table::borrow_mut(&mut round_holder.rounds, round_id_to_close);

        round_to_close.status = ROUND_ENDED;

        event::emit(RoundCloseEvent {
            id: round_id_to_close
        });
    }


    public entry fun bet_on_next_round(user: &signer, amount: u64) acquires RoundHolder {
        // TODO: check if round is properly setup
        let user_addr = signer::address_of(user);
        let user_balance = coin::balance<aptos_coin::AptosCoin>(user_addr);
        assert!(user_balance >= amount, E_NOT_ENOUGH_FUNDS);

        aptos_account::transfer(user, @crash, amount);

        // TODO: register bet amount and the fact that user's playing
        let round_holder = borrow_global_mut<RoundHolder>(@crash);

        let round_state = table::borrow_mut(&mut round_holder.rounds, round_holder.current);
        table::add(&mut round_state.userStates, user_addr, PlayerRoundState {
            amount,
            claimed_multiplier: option::none<u64>(),
            claimed: false
        });

        event::emit(UserBetEvent {
            user: user_addr,
            amount: amount,
            round_id: round_holder.current
        });
    }

    public entry fun claim_multiplier(user: &signer, multiplier: u64) acquires RoundHolder {
        is_valid_multiplier(multiplier);

        // Check if user is part of the current round
        let round_holder = borrow_global_mut<RoundHolder>(@crash);
        let current_round = table::borrow_mut(&mut round_holder.rounds, round_holder.current);
        let user_address = signer::address_of(user);
        is_registered_in_round(user_address, current_round);

        // We now ensure that the user hasn't already claimed a multiplier
        let player_status_in_round = table::borrow_mut(&mut current_round.userStates, user_address);
        assert!(option::is_none(&player_status_in_round.claimed_multiplier), E_ALREADY_CLAIMED_MULTIPLIER);

        // All good, we can claim
        player_status_in_round.claimed_multiplier = option::some(multiplier);

        event::emit(ClaimMultiplierEvent {
            user: user_address,
            multiplier
        });
    }

    /// Claim my rewards iterates over all the rounds a user is a part of and computes amount * claimed_multiplier
    public entry fun claim_my_rewards(user: &signer, round_id: u64) acquires RoundHolder, Config {
        let roundHolder = borrow_global_mut<RoundHolder>(@crash);
        let round = table::borrow_mut(&mut roundHolder.rounds, round_id);

        let user_address = signer::address_of(user);
        assert!(round.status == ROUND_ENDED, E_ROUND_NOT_FINISHED);
        ensure_rewards_not_claimed_yet(user_address, round);

        let reward_amount = compute_round_reward_for(user_address, round);
        let user_round_state = table::borrow_mut(&mut round.userStates, user_address);
        user_round_state.claimed = true;

        // TODO: transfer rewards
        let game_balance = coin::balance<aptos_coin::AptosCoin>(@crash);
        assert!(game_balance >= reward_amount, E_NOT_ENOUGH_FUNDS);

        let config = borrow_global<Config>(@crash);
        let admin_signer = create_signer_with_capability(&config.signer_cap);
        aptos_account::transfer(&admin_signer, user_address, reward_amount);

        event::emit(ClaimRewardsEvent {
            round: round_id,
            user: user_address,
            rewards: reward_amount
        });
    }

    fun compute_round_reward_for(user: address, round: &Round): u64 {
        let reward = 0;

        if (table::contains(&round.userStates, user)) {
            let playerState = table::borrow(&round.userStates, user);

            if (playerState.claimed == false && option::is_some(&playerState.claimed_multiplier)) {
                // FIXME: multiplier is [100;1_000[, we need to divide by min?
                // NOTE: whatever's left over is of no concern to us, we'll just divide and call it a day
                let multiplier = option::borrow(&playerState.claimed_multiplier);
                reward = (*multiplier / MIN_MULTIPLIER) * playerState.amount;
            }
        };

        reward
    }

    // Guards
    fun ensure_rewards_not_claimed_yet(user: address, round: &Round) {
        let user_state = table::borrow(&round.userStates, user);
        assert!(user_state.claimed == false, E_ALREADY_CLAIMED_REWARDS);
    }


    // Utils
    fun reward_for(round_id: u64, user: address): u64 acquires RoundHolder {
        let roundHolder = borrow_global<RoundHolder>(@crash);
        let round = table::borrow(&roundHolder.rounds, round_id);
        assert!(round.status == ROUND_ENDED, E_ROUND_NOT_FINISHED);

        let reward = 0;
        if (table::contains(&round.userStates, user)) {
            let playerState = table::borrow(&round.userStates, user);

            if (playerState.claimed == false && option::is_some(&playerState.claimed_multiplier)) {
                let multiplier = option::borrow(&playerState.claimed_multiplier);
                reward = *multiplier * playerState.amount;
            }
        };

        reward
    }


    fun roll_multiplier(): u64 {
        aptos_framework::randomness::u64_range(0, 1_000)
    }


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
    fun get_current_round(): u64 acquires RoundHolder {
        let round_holder = borrow_global<RoundHolder>(@crash);
        round_holder.current
    }

    #[view]
    fun get_next_round(): u64 acquires RoundHolder {
        get_current_round() + 1
    }

    #[view]
    public fun get_admin(): address acquires Config {
        let config = borrow_global<Config>(@crash);
        config.admin
    }


    #[view]
    public fun get_user_rewards_for_round(user: address, round_id: u64): u64 acquires RoundHolder {
        let rewards = 0;
        let round_holder = borrow_global<RoundHolder>(@crash);
        let round = table::borrow(&round_holder.rounds, round_id);

        if (table::contains(&round.userStates, user)) {
            rewards = table::borrow(&round.userStates, user).amount;
        };

        rewards
    }
}