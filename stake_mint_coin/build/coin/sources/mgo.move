#[allow(unused_use, unused_const)]
module coin::mgo {
    use std::option;
    use mgo::url::{Self, Url};
    use mgo::coin::{Self, TreasuryCap};
    use mgo::transfer;
    use mgo::tx_context::TxContext;
    use mgo::package::{Self, Publisher};

    public struct MGOW has drop {}

    // fun init(otw: MGO, ctx: &mut TxContext) {
    //     let publisher = package::claim(otw, ctx);
    //     // 管理员所有权给合约发布者
    //     transfer::public_transfer(publisher, ctx.sender());
    // }

    public fun set_coininfo(
        decimals: u8,
        symbol: vector<u8>,
        name: vector<u8>,
        description: vector<u8>,
        icon_url: vector<u8>,
        witness: MGOW,
        _stakeplatform_cap: &Publisher,
        ctx: &mut TxContext,
    ) {
        let coin_url = option::some(url::new_unsafe_from_bytes(icon_url));
        let (treasury, metadata) = coin::create_currency(
            witness,
            decimals,
            symbol,
            name,
            description,
            coin_url,
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender());
    }

    public entry fun mint_coin(
        treasury_cap: &mut TreasuryCap<MGOW>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient)
    }
}