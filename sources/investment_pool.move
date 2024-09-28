module crab_project::investment_pool {
    use std::signer;
    use aptos_framework::coin::{Self, Coin};
    use crab_project::crab_token;
    use aptos_std::table::{Self, Table};
    use crab_project::epoch;

    struct LiquidityPool has key {
        total_liquidity: u64,
        usdc_reserve: Coin<USDC>,
        investor_stakes: Table<address, u64>,
        total_profit: u64,
        last_profit_distribution: u64,
    }

    struct USDC {}

    const E_NOT_ENOUGH_BALANCE: u64 = 1;
    const E_NOT_AUTHORIZED: u64 = 2;
    const E_POOL_INSUFFICIENT_LIQUIDITY: u64 = 3;

    public entry fun initialize(admin: &signer) {
        assert!(signer::address_of(admin) == @crab_project, E_NOT_AUTHORIZED);
        move_to(admin, LiquidityPool { 
            total_liquidity: 0,
            usdc_reserve: coin::zero<USDC>(),
            investor_stakes: table::new(),
            total_profit: 0,
            last_profit_distribution: 0,
        });
    }

    public entry fun invest(investor: &signer, amount: u64) acquires LiquidityPool {
        let investor_address = signer::address_of(investor);
        
        assert!(coin::balance<USDC>(investor_address) >= amount, E_NOT_ENOUGH_BALANCE);

        let usdc_coins = coin::withdraw<USDC>(investor, amount);
        let pool = borrow_global_mut<LiquidityPool>(@crab_project);
        coin::merge(&mut pool.usdc_reserve, usdc_coins);

        pool.total_liquidity = pool.total_liquidity + amount;
        
        let current_stake = if (table::contains(&pool.investor_stakes, investor_address)) {
            *table::borrow(&pool.investor_stakes, investor_address)
        } else {
            0
        };
        table::upsert(&mut pool.investor_stakes, investor_address, current_stake + amount);

        crab_token::mint(investor, investor_address, amount);
    }

     public entry fun withdraw(investor: &signer, amount: u64) acquires LiquidityPool {
        let investor_address = signer::address_of(investor);
        let pool = borrow_global_mut<LiquidityPool>(@crab_project);
        
        assert!(table::contains(&pool.investor_stakes, investor_address), E_NOT_ENOUGH_BALANCE);
        let current_stake = *table::borrow(&pool.investor_stakes, investor_address);
        assert!(current_stake >= amount, E_NOT_ENOUGH_BALANCE);
        assert!(coin::value(&pool.usdc_reserve) >= amount, E_POOL_INSUFFICIENT_LIQUIDITY);

        table::upsert(&mut pool.investor_stakes, investor_address, current_stake - amount);
        pool.total_liquidity = pool.total_liquidity - amount;

        let withdrawn_coins = coin::extract(&mut pool.usdc_reserve, amount);
        coin::deposit(investor_address, withdrawn_coins);

        crab_token::burn(investor, amount);
    }

    public entry fun distribute_profits(admin: &signer, profit_amount: u64) acquires LiquidityPool {
        assert!(signer::address_of(admin) == @crab_project, E_NOT_AUTHORIZED);
        let pool = borrow_global_mut<LiquidityPool>(@crab_project);
        
        pool.total_profit = pool.total_profit + profit_amount;
        pool.last_profit_distribution = epoch::now();
    }

    #[view]
    public fun total_liquidity(): u64 acquires LiquidityPool {
        borrow_global<LiquidityPool>(@crab_project).total_liquidity
    }

    #[view]
    public fun investor_stake(investor: address): u64 acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool>(@crab_project);
        if (table::contains(&pool.investor_stakes, investor)) {
            *table::borrow(&pool.investor_stakes, investor)
        } else {
            0
        }
    }

    #[view]
    public fun total_profit(): u64 acquires LiquidityPool {
        borrow_global<LiquidityPool>(@crab_project).total_profit
    }

    #[view]
    public fun last_profit_distribution(): u64 acquires LiquidityPool {
        borrow_global<LiquidityPool>(@crab_project).last_profit_distribution
    }

    #[test_only]
    public fun initialize_for_test(admin: &signer) {
        initialize(admin);
    }
}