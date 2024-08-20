#[allow(unused_use, unused_const)]
module stake::mgo {
    use std::option;
    use mgo::url;
    use mgo::coin::{Self, TreasuryCap};
    use mgo::transfer;
    use mgo::tx_context::TxContext;

    public struct MGO has drop {}

    fun init(witness: MGO, ctx: &mut TxContext) {
        let coin_url = url::new_unsafe_from_bytes(b"https://image.devnet.mangonetwork.io/img/token/mgo-logo.png");
        let (treasury, metadata) = coin::create_currency(
            witness,
            6,
            b"MGO",
            b"MGO",
            b"MGO",
            option::some(coin_url),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender());
    }

    public entry fun mint(
        treasury_cap: &mut TreasuryCap<MGO>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient)
    }
}