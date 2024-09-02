#[allow(unused_use, unused_const)]
module stake::staking_platform {
    use std::debug;
    use std::vector;
    use std::string::{Self, String, utf8};
    use std::option::{Self, Option};
    use std::type_name::{Self, TypeName};
    use mgo::address;
    use mgo::address::from_bytes;
    use mgo::transfer;
    use mgo::event;
    use mgo::object::{Self, ID, UID};
    use mgo::coin::{Self, Coin};
    use mgo::tx_context::TxContext;
    use mgo::balance::{Self, Balance};
    use mgo::clock;
    use mgo::package::{Self, Publisher};
    use mgo::table::{Self, Table};
    use mgo::dynamic_field as field;

    use stake::reward_pool::{sum_profit, cal_days_between};

    const EStakeCoinAmountInsufficient: u64 = 0;
    const ERewardRateIncorrect: u64 = 1;
    const EStakeTimeNotReached: u64 = 2;
    const EStakingPeriodInsufficient: u64 = 3;
    const ETreasuryInsufficient: u64 = 4;

    // 质押平台管理员
    public struct STAKING_PLATFORM has drop {}

    public struct StakingPlatform<phantom COIN> has store, key {
        id: UID,
        admin: address,
        annual_rate: u64,
        currency_type: TypeName,
        // 计数器
        total_stake_record_count: u64,
        total_staker_count: u64,
        total_staked_amount: u64,
        stake_event_counter: u64,
        unstake_event_counter: u64,
        create_stakingplatform_event_counter: u64,
        update_platform_event_counter: u64,
        withdraw_reward_event_counter: u64,
        // 质押记录
        stake_address_record_table: Table<address, Table<u64, StakeInfo>>,
    }

    // 定义一个自增计数器
    public struct PlatformCounter has store, key {
        id: UID,
        create_platform_event_counter: u64,
        create_rewardpool_event_counter: u64,
    }

    // 质押信息
    public struct StakeInfo has store, key {
        id: UID,
        staker: address,
        stake_amount: u64,
        annual_rate: u64,
        start_time: u64,
        end_time: u64,
        duration_days: u64,
        last_withdraw_time: u64,
        stake_status: bool,
    }

    // 奖池信息
    public struct RewardPoolInfo<phantom COIN> has store, key {
        id: UID,
        admin: address,
        // 质押天数
        stake_days: u64,
        // 收益总量
        total_amount: u64,
        // 质押总人数
        total_stakers: u64,
        currency_type: TypeName,
        rewardpool_address_table: Table<address, Table<u64, vector<Coin<COIN>>>>,
    }

    // 创建质押平台事件
    public struct CreateStakePlatformEvent has copy, drop {
        event_counter: u64,
        stakingplatform_id: ID,
        annual_rate: u64,
        currency_type: TypeName,
    }

    // 更新质押平台事件
    public struct UpdateStakePlatformEvent has copy, drop {
        event_counter: u64,
        annual_rate: u64,
        stakingplatform_id: ID,
    }

    // 创建奖池事件
    public struct CreateRewardPoolEvent has copy, drop {
        event_counter: u64,
        rewardpool_id: ID,
        currency_type: TypeName,
    }

    // 用户提取奖励事件
    public struct WithdrawRewardEvent has copy, drop {
        event_counter: u64,
        withdarwer: address,
        withdraw_amount: u64,
        withdraw_time: u64,
        stakerecord_id: u64,
    }

    // 质押事件：质押者，质押数量，质押开始时间，质押时长
    public struct StakeEvent has copy, drop {
        stake_event_counter: u64, // 总的 所有address 1-999
        staking_platform_id: ID,
        staker: address,
        stake_amount: u64,
        currency_type: TypeName,
        annual_rate: u64,
        start_time: u64,
        duration: u64,
        end_time: u64,
        address_stake_counter: u64, // 当前账户 1-999
        total_stake_record_count: u64,
        total_staker_count: u64,
        total_staked_amount: u64,
    }

    // 解质押事件：质押者，质押数量，质押奖励
    public struct UnstakeEvent has copy, drop {
        unstake_event_counter: u64,
        unstaker: address,
        unstake_amount: u64,
        unstake_time: u64,
        stake_id: u64,
    }

    // 初始化质押平台管理员
    fun init(otw: STAKING_PLATFORM, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);
        let platform_counter = PlatformCounter {
            id: object::new(ctx),
            create_platform_event_counter: 0,
            create_rewardpool_event_counter: 0,
        };
        // 管理员所有权给合约发布者
        transfer::public_transfer(publisher, ctx.sender());
        transfer::public_transfer(platform_counter, ctx.sender());
    }

    // 管理员创建质押平台
    public entry fun create_staking_platform<COIN>(
        annual_rate: u64,
        platform_counter: &mut PlatformCounter,
        _stakeplatform_cap: &Publisher,
        ctx: &mut TxContext
    ) {
        assert!(annual_rate >= 0 && annual_rate <= 10000, ERewardRateIncorrect);

        let staking_platform = StakingPlatform {
            id: object::new(ctx),
            admin: ctx.sender(),
            annual_rate,
            currency_type: type_name::get<COIN>(),
            total_stake_record_count: 0,
            total_staker_count: 0,
            total_staked_amount: 0,
            stake_event_counter: 0,
            unstake_event_counter: 0,
            create_stakingplatform_event_counter: 0,
            update_platform_event_counter: 0,
            withdraw_reward_event_counter: 0,
            stake_address_record_table: table::new<address, Table<u64, StakeInfo>>(ctx),
        };

        platform_counter.create_platform_event_counter = platform_counter.create_platform_event_counter + 1;

        event::emit(CreateStakePlatformEvent {
            event_counter: platform_counter.create_platform_event_counter,
            stakingplatform_id: object::uid_to_inner(&staking_platform.id),
            annual_rate,
            currency_type: type_name::get<COIN>(),
        });

        // 用户可以自由交互质押平台
        transfer::share_object<StakingPlatform<COIN>>(staking_platform);
    }

    // 管理员创建收益池
    public entry fun create_reward_pool<COIN>(
        platform_counter: &mut PlatformCounter,
        _rewardpool_cap: &Publisher,
        ctx: &mut TxContext
    ) {
        let rewardpool_info = RewardPoolInfo<COIN> {
            id: object::new(ctx),
            admin: ctx.sender(),
            stake_days: 0,
            total_amount: 0,
            total_stakers: 0,
            currency_type: type_name::get<COIN>(),
            rewardpool_address_table: table::new<address, Table<u64, vector<Coin<COIN>>>>(ctx),
        };

        platform_counter.create_rewardpool_event_counter = platform_counter.create_rewardpool_event_counter + 1;

        event::emit(CreateRewardPoolEvent {
            event_counter: platform_counter.create_rewardpool_event_counter,
            rewardpool_id: object::uid_to_inner(&rewardpool_info.id),
            currency_type: type_name::get<COIN>(),
        });

        // 管理员可以从收益池提取收益给用户
        transfer::public_transfer(rewardpool_info, ctx.sender());
    }

    // 逻辑：输入金库，直接划出一份用户reward，然后再根据days化成n份，每天10点打一份。
    // stake发生时，管理员把对应奖励预存入奖池
    public entry fun pre_reward_pool<COIN>(
        staker: address,
        stake_amount: u64,
        duration_days: u64,
        annual_rate: u64,
        address_stake_counter: u64,
        treasury_coin: &mut Coin<COIN>,
        rewardpool_info: &mut RewardPoolInfo<COIN>,
        ctx: &mut TxContext
    ) {
        // 当前账户本次质押可获奖励 sum_reward=1360
        let sum_reward = sum_profit(stake_amount, duration_days, annual_rate);
        // 金库余额要大于sum_reward
        assert!(treasury_coin.value() > sum_reward, ETreasuryInsufficient);
        // 从金库中分出此次质押的sum_reward
        let mut sum_reward = treasury_coin.split(sum_reward, ctx);

        // 把sum_reward分成days份vector<day_reward>
        let mut day_reward = sum_reward.divide_into_n(duration_days, ctx);
        vector::push_back(&mut day_reward, sum_reward);

        // 如果当前账户第一次存入奖励，则创建一个新的奖励池，hashmap为质押编号：奖励
        if (address_stake_counter == 1) {
            // 质押编号表
            let mut rewardpool_number_coin_table = table::new<u64, vector<Coin<COIN>>>(ctx);
            // 奖励存入质押编号表 质押编号：奖励
            table::add<u64, vector<Coin<COIN>>>(&mut rewardpool_number_coin_table, address_stake_counter, day_reward);
            table::add<address, Table<u64, vector<Coin<COIN>>>>(&mut rewardpool_info.rewardpool_address_table, staker, rewardpool_number_coin_table);
        } else {
            // 根据账户地址取出当前账户质押编号表 编号：奖励
            let rewardpool_number_coin_table = table::borrow_mut<address, Table<u64, vector<Coin<COIN>>>>(&mut rewardpool_info.rewardpool_address_table, staker);
            // 奖励存入质押编号表 质押编号：奖励
            table::add<u64, vector<Coin<COIN>>>(rewardpool_number_coin_table, address_stake_counter, day_reward);
        };
    }

    // 管理员更新质押平台信息
    public entry fun update_staking_platform<COIN>(
        staking_platform: &mut StakingPlatform<COIN>,
        annual_rate: u64,
        _stakeplatform_cap: &Publisher,
    ) {
        staking_platform.annual_rate = annual_rate;

        staking_platform.update_platform_event_counter = staking_platform.update_platform_event_counter + 1;

        event::emit(UpdateStakePlatformEvent {
            event_counter: staking_platform.update_platform_event_counter,
            annual_rate,
            stakingplatform_id: object::uid_to_inner(&staking_platform.id),
        });
    }

    // 质押代币
    public entry fun stake<COIN>(
        stake_amount: u64,
        duration_days: u64,
        mut stake_coin: Coin<COIN>,
        current_clock: &clock::Clock,
        staking_platform: &mut StakingPlatform<COIN>,
        ctx: &mut TxContext
    ) {
        // 传入代币数量要大于等于质押数量
        assert!(stake_coin.value() >= stake_amount, EStakeCoinAmountInsufficient);

        // 获取今天10点的时间戳
        let ten_am_timestamp = get_today_ten_am_timestamp(current_clock);
        // 10点前今天，10点后明天
        let start_timestamp = if (current_clock.timestamp_ms() <= ten_am_timestamp) {
            ten_am_timestamp
        } else {
            ten_am_timestamp + 24 * 60 * 60 * 1000
        };
        // 提取时间设置为质押开始时间
        let last_withdraw_time = start_timestamp;
        // 结束质押当天10点
        let end_timestamp = start_timestamp + duration_days * 24 * 60 * 60 * 1000;

        // 记录质押信息结构体
        let mut stake_info = StakeInfo {
            id: object::new(ctx),
            staker: ctx.sender(),
            stake_amount,
            annual_rate: staking_platform.annual_rate,
            start_time: start_timestamp,
            duration_days,
            end_time: end_timestamp,
            last_withdraw_time,
            stake_status: true,
        };

        // 质押代币直接锁仓 存入质押信息结构体
        // 留下质押数量的代币，其余代币返还给质押者
        if (stake_coin.value() > stake_amount) {
            let stake_amount_coin = stake_coin.split(stake_amount, ctx);
            transfer::public_transfer(stake_coin, ctx.sender());
            field::add(&mut stake_info.id, b"stake_coin", stake_amount_coin);
        } else {
            field::add(&mut stake_info.id, b"stake_coin", stake_coin);
        };

        // 质押信息放入质押编号_信息表 Table<质押编号: 质押信息>
        // 质押平台中是否已经有当前地址的质押记录
        let contains = table::contains<address, Table<u64, StakeInfo>>(&staking_platform.stake_address_record_table, ctx.sender());
        // 如果已经有当前地址的质押记录，则质押编号+1
        let (address_stake_counter, stake_number_info_table) = if (contains) {
            // 取出当前账户质押编号
            let mut stake_number_info_table = table::remove<address, Table<u64, StakeInfo>>(&mut staking_platform.stake_address_record_table, ctx.sender());
            // 当前账户质押编号 = 上次质押编号表长度 + 1
            let address_stake_counter = stake_number_info_table.length() + 1;
            // 第n次质押 质押编号：n，质押信息：当前地址的第n次质押信息
            table::add(&mut stake_number_info_table, address_stake_counter, stake_info);
            (address_stake_counter, stake_number_info_table)
        } else {
            // 当前账户无质押记录，新建一个质押编号表，设置第一次质押编号为1
            let mut stake_number_info_table = table::new<u64, StakeInfo>(ctx);
            let address_stake_counter = 1;
            // 第一次质押 质押编号：1，质押信息：当前地址的第一条质押信息
            table::add(&mut stake_number_info_table, address_stake_counter, stake_info);
            (address_stake_counter, stake_number_info_table)
        };
        table::add<address, Table<u64, StakeInfo>>(&mut staking_platform.stake_address_record_table, ctx.sender(), stake_number_info_table);

        // 质押编号_信息表放入质押地址_记录表 <质押者地址: Table<质押编号：质押信息>>
        // 总质押条数
        staking_platform.total_stake_record_count = staking_platform.total_stake_record_count + 1;
        // 质押人数 = 质押地址表长度
        staking_platform.total_staker_count = staking_platform.stake_address_record_table.length();
        staking_platform.total_staked_amount = staking_platform.total_staked_amount + stake_amount;
        staking_platform.stake_event_counter = staking_platform.stake_event_counter + 1;

        // 触发质押事件
        event::emit(StakeEvent {
            // 本次质押信息
            stake_event_counter: staking_platform.stake_event_counter,
            staking_platform_id: object::uid_to_inner(&staking_platform.id),
            staker: ctx.sender(),
            stake_amount,
            currency_type: staking_platform.currency_type,
            annual_rate: staking_platform.annual_rate,
            start_time: start_timestamp,
            duration: duration_days,
            end_time: end_timestamp,
            // 当前账户质押编号/计数
            address_stake_counter,
            // 计数器 总共质押次数，总共质押人数，总共质押金额
            total_stake_record_count: staking_platform.total_stake_record_count,
            total_staker_count: staking_platform.total_staker_count,
            total_staked_amount: staking_platform.total_staked_amount,
        });
    }

    // 解质押代币 质押到期后随时可以解除
    public entry fun un_stake<COIN>(
        user_address: address,
        address_stake_counter: u64,
        current_clock: &clock::Clock,
        rewardpool_info: &mut RewardPoolInfo<COIN>,
        staking_platform: &mut StakingPlatform<COIN>,
        test: bool,
        test_current_timestamp_ms: u64, // 1726135200000
    ) {
        // 质押没到期不可解除
        let mut stake_number_info_table = table::remove<address, Table<u64, StakeInfo>>(&mut staking_platform.stake_address_record_table, user_address);
        let mut stake_info = table::remove<u64, StakeInfo>(&mut stake_number_info_table, address_stake_counter);
        let end_timestamp = stake_info.end_time;
        // 测试用
        let current_timestamp_ms = if (test) { // 1726135200000
            test_current_timestamp_ms
        } else {
            clock::timestamp_ms(current_clock)
        };
        // 质押没到期不可解除
        assert!(current_timestamp_ms >= end_timestamp, EStakeTimeNotReached);

        // 返还质押代币
        let stake_coin = field::remove<vector<u8>,Coin<COIN>>(&mut stake_info.id, b"stake_coin");
        transfer::public_transfer(stake_coin, user_address);

        // 判断奖励是否有剩余
        let rewardpool_number_coin_table = table::borrow(&rewardpool_info.rewardpool_address_table, user_address);
        let vector_day_reward = table::borrow(rewardpool_number_coin_table, address_stake_counter);

        // 质押到现在的天数
        let current_duration_ms = current_timestamp_ms - stake_info.start_time; // 1726135200000 - 1725271200000
        let current_timestamp_days = current_duration_ms / (24 * 60 * 60 * 1000); // 10

        // 更新质押状态
        stake_info.stake_status = false;
        let stake_amount = stake_info.stake_amount;
        table::add(&mut stake_number_info_table, address_stake_counter, stake_info);
        table::add<address, Table<u64, StakeInfo>>(&mut staking_platform.stake_address_record_table, user_address, stake_number_info_table);

        if (vector::length(vector_day_reward) > 0) {
            // 返还剩余奖励
            withdraw_reward(user_address, address_stake_counter, current_clock, rewardpool_info, staking_platform, test, current_timestamp_days);
        };

        // 触发解质押事件
        staking_platform.unstake_event_counter = staking_platform.unstake_event_counter + 1;

        event::emit(UnstakeEvent {
            unstake_event_counter: staking_platform.unstake_event_counter,
            unstaker: user_address,
            unstake_amount: stake_amount,
            unstake_time: current_timestamp_ms,
            stake_id: address_stake_counter,
        });
    }

    // 用户提取奖励 只要池子有钱就可以提取奖励
    public entry fun withdraw_reward<COIN>(
        user_address: address,
        address_stake_counter: u64,
        current_clock: &clock::Clock,
        rewardpool_info: &mut RewardPoolInfo<COIN>,
        staking_platform: &mut StakingPlatform<COIN>,
        test: bool,
        test_current_duration_days: u64, // 10
    ) {
        // 根据账户地址从质押账户表取出质押编号表
        let stake_number_info_table = table::borrow_mut<address, Table<u64, StakeInfo>>(&mut staking_platform.stake_address_record_table, user_address);
        // 根据质押编号从质押编号表取出质押信息
        let stake_number_info = table::borrow_mut<u64, StakeInfo>(stake_number_info_table, address_stake_counter);

        // 测试用
        let current_duration_days = if (test) { // 10
            test_current_duration_days
        } else {
            cal_days_between(current_clock.timestamp_ms(), stake_number_info.last_withdraw_time)
        };

        // 要求与上次提取时间满1整天才能提取
        assert!(current_duration_days >= 1, EStakingPeriodInsufficient); // 10
        // 获取今天10点的时间戳
        let ten_am_timestamp = get_today_ten_am_timestamp(current_clock);
        // 更新本次提取时间
        stake_number_info.last_withdraw_time = ten_am_timestamp;

        // 根据账户地址从奖池取出奖励编号表
        let mut rewardpool_number_coin_table = table::remove(&mut rewardpool_info.rewardpool_address_table, user_address);
        // 根据质押编号从奖励编号表取出预存的奖励向量
        let mut vector_reward: vector<Coin<COIN>> = table::remove(&mut rewardpool_number_coin_table, address_stake_counter);

        // 取出vector_day_reward的第days份day_reward
        // 先取出来一天的奖励
        let mut extractable_reward = vector::pop_back(&mut vector_reward);
        // 取出剩下的天数的奖励
        let mut i = 1;
        while (i < current_duration_days) {
            if (!vector::is_empty(&vector_reward)) {
                let day_reward = vector::pop_back(&mut vector_reward);
                extractable_reward.join(day_reward);
            } else {
                // 处理向量为空的情况，比如退出循环或其他逻辑
                break
            };
            i = i + 1;
        };

        // 未使用的reward打回奖池，若已取完奖励，则奖池为空向量
        table::add(&mut rewardpool_number_coin_table, address_stake_counter, vector_reward);
        table::add(&mut rewardpool_info.rewardpool_address_table, user_address, rewardpool_number_coin_table);

        // 把可提取的奖励打给用户
        let withdraw_amount = extractable_reward.value();
        transfer::public_transfer(extractable_reward, user_address);

        staking_platform.withdraw_reward_event_counter = staking_platform.withdraw_reward_event_counter + 1;

        event::emit(WithdrawRewardEvent {
            event_counter: staking_platform.withdraw_reward_event_counter,
            withdarwer: user_address,
            withdraw_amount,
            withdraw_time: current_clock.timestamp_ms(),
            stakerecord_id: address_stake_counter,
        });
    }

    fun get_today_ten_am_timestamp(current_clock: &clock::Clock): u64 {
        // 获取当前时间戳（毫秒）
        let current_day_timestamp = current_clock.timestamp_ms();
        // 计算今天0点的时间戳
        let today_start_timestamp = (current_day_timestamp / (24 * 60 * 60 * 1000)) * (24 * 60 * 60 * 1000);
        // 计算今天10点的时间戳
        let ten_am_timestamp = today_start_timestamp + (10 * 60 * 60 * 1000);

        ten_am_timestamp
    }

    public struct COIN has copy, drop, store {}

    // #[test]
    // fun test_create_stake() {
    //     use std::debug;
    //     use mgo::test_scenario::{Self, next_tx, ctx};
    //     use stake::reward_pool::{Self, REWARD_POOL};
    //
    //
    //     let admin = @0xA;
    //     let mut scenario = test_scenario::begin(admin);
    //     // 初始化，生成质押平台publisher和奖池publisher和计数器
    //     init(STAKING_PLATFORM {}, ctx(&mut scenario));
    //     next_tx(&mut scenario, admin);
    //     // 新的场景 admin是新的sender
    //     let platform_publisher = test_scenario::take_from_address<Publisher>(&scenario, admin);
    //     let mut platform_counter = test_scenario::take_from_address<PlatformCounter>(&scenario, admin);
    //
    //     create_staking_platform<Coin<COIN>>(500, &mut platform_counter, &platform_publisher, ctx(&mut scenario));
    //     let effects = test_scenario::next_tx(&mut scenario, admin);
    //     let events = test_scenario::shared(&effects);
    //     debug::print(&events);
    //
    //     let staking_platform_id_object = vector::borrow(&events, 0);
    //     let staking_platform_id_bytes = object::id_to_bytes(staking_platform_id_object);
    //     debug::print(&staking_platform_id_bytes);
    //
    //     stake(1000000, 10, Coin<COIN>, 0x6, staking_platform_id_bytes, ctx(&mut scenario));
    //
    //     test_scenario::return_to_address<Publisher>(admin, platform_publisher);
    //     test_scenario::return_to_address<PlatformCounter>(admin, platform_counter);
    //     scenario.end();
    // }
}