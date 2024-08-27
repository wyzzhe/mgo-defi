#[allow(unused_use, unused_const)]
module stake::reward_pool {
    use std::type_name::{Self, TypeName};
    use std::vector;
    use mgo::object::{Self, ID, UID};
    use mgo::coin::{Self, Coin};
    use mgo::event;
    use mgo::package::{Self, Publisher};
    use mgo::table::{Self,Table};
    use mgo::transfer;
    use mgo::tx_context::TxContext;
    use mgo::table_vec::TableVec;
    use mgo::dynamic_field as field;
    use mgo::clock;

    use stake::staking_platform::RewardPoolInfo;

    // 奖池管理员
    public struct REWARD_POOL has drop {}

    // 初始化收益池管理员
    fun init(otw: REWARD_POOL, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);
        // 管理员所有权给合约发布者
        transfer::public_transfer(publisher, ctx.sender());
    }

    public fun sum_profit(
        amount: u64,
        // x天 365天
        duration_ms: u64,
        annual_rate: u64,
    ): (u64, u64) {
        let annual_reward = amount * annual_rate / 10000;
        let day_reward = annual_reward / 365;

        let duration_in_days = duration_ms / 86400000;

        let sum_reward = day_reward * duration_in_days;
        (sum_reward, duration_in_days)
    }

    public fun cal_days_between(last_timestamp: u64, current_timestamp: u64): u64 {
        // 一天的秒数 (24小时 * 60分钟 * 60秒)
        let seconds_in_a_day: u64 = 86400000;

        // 确保当前时间戳不小于开始时间戳
        assert!(current_timestamp >= last_timestamp, 0);

        // 计算时间戳之间的秒数差
        let difference_in_seconds: u64 = current_timestamp - last_timestamp;

        // 将秒数转换为天数
        let days: u64 = difference_in_seconds / seconds_in_a_day;

        days
    }

    #[test]
    fun test_cal_days_between() {
        use std::debug;

        let start_timestamp = 1689072000000;
        let current_timestamp = 1689158400000;
        let days = cal_days_between(start_timestamp, current_timestamp);

        debug::print(&days);
    }
}