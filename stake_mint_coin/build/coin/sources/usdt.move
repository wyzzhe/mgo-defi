#[allow(unused_use, unused_const)]
module coin::usdt {
    use std::option;
    use mgo::url;
    use mgo::coin::{Self, TreasuryCap};
    use mgo::transfer;
    use mgo::tx_context::TxContext;

    public struct USDT has drop {}

    fun init(witness: USDT, ctx: &mut TxContext) {
        let coin_url = url::new_unsafe_from_bytes(b"https://cryptologos.cc/logos/tether-usdt-logo.png?v=032");
        let (treasury, metadata) = coin::create_currency(
            witness,
            6,
            b"USDT",
            b"USDT",
            b"USDT",
            option::some(coin_url),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender());
    }

    public entry fun mint(
        treasury_cap: &mut TreasuryCap<USDT>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient)
    }

    // 测试函数
    #[test]
    fun test_mint() {
        use mgo::test_scenario::{Self, next_tx, ctx};

        let admin = @0xA;
        let mut scenario = test_scenario::begin(admin);

        init(USDT {}, ctx(&mut scenario));

        next_tx(&mut scenario, admin);

        let mut treasurycap = test_scenario::take_from_sender<TreasuryCap<USDT>>(&scenario);
        mint(&mut treasurycap, 1000, admin, ctx(&mut scenario));
        test_scenario::return_to_address<TreasuryCap<USDT>>(admin, treasurycap);

        scenario.end();
    }
}