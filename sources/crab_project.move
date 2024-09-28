module crab_project::crab_project {
    use crab_project::crab_token;
    use crab_project::investment_pool;
    use crab_project::epoch;

    fun init_module(admin: &signer) {
        crab_token::initialize(admin);
        investment_pool::initialize(admin);
        epoch::initialize(admin);
    }

    #[test_only]
    use aptos_framework::account;

    #[test(admin = @crab_project)]
    fun test_initialize(admin: &signer) {
        account::create_account_for_test(@crab_project);
        init_module(admin);
    }
}