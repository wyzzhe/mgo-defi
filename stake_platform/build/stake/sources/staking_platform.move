#[allow(unused_use, unused_const)]
module stake::staking_platform {
    use std::vector;
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::type_name::{Self, TypeName};
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
        // 其他字段
    }

    // 质押信息
    public struct StakeInfo has store, key {
        id: UID,
        staker: address,
        stake_amount: u64,
        annual_rate: u64,
        start_time: u64,
        end_time: u64,
        duration: u64,
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
        admin: address,
        annual_rate: u64,
        currency_type: TypeName,
    }

    // 更新质押平台事件
    public struct UpdateStakePlatformEvent has copy, drop {
        event_counter: u64,
        admin: address,
        annual_rate: u64,
        stakingplatform_id: ID,
    }

    // 创建奖池事件
    public struct CreateRewardPoolEvent has copy, drop {
        admin: address,
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

        event::emit(CreateStakePlatformEvent {
            event_counter: platform_counter.create_platform_event_counter,
            stakingplatform_id: object::uid_to_inner(&staking_platform.id),
            admin: ctx.sender(),
            annual_rate,
            currency_type: type_name::get<COIN>(),
        });

        platform_counter.create_platform_event_counter = platform_counter.create_platform_event_counter + 1;

        // 用户可以自由交互质押平台
        transfer::share_object<StakingPlatform<COIN>>(staking_platform);
    }

    // 管理员创建收益池
    public entry fun create_reward_pool<COIN>(
        _collection_cap: &Publisher,
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

        event::emit(CreateRewardPoolEvent {
            admin: ctx.sender(),
        });

        // 用户可以从收益池提取收益
        transfer::share_object(rewardpool_info);
    }

    // 逻辑：输入金库，直接划出一份用户reward，然后再根据days化成n份，每天10点打一份。
    // stake发生时，管理员把对应奖励预存入奖池
    public entry fun pre_reward_pool<COIN>(
        staker: address,
        amount: u64,
        duration: u64,
        annual_rate: u64,
        stake_number: u64,
        treasury_coin: &mut Coin<COIN>,
        rewardpool_info: &mut RewardPoolInfo<COIN>,
        ctx: &mut TxContext
    ) {
        // reward
        let sum_reward = sum_profit(amount, duration, annual_rate);
        // 金库余额要大于sum_reward
        assert!(treasury_coin.value() > sum_reward, ETreasuryInsufficient);

        // 从金库中分出此次质押的sum_reward
        let mut sum_reward = treasury_coin.split(sum_reward, ctx);

        // 把sum_reward分成days份vector<day_reward>
        let mut vector_day_reward = sum_reward.divide_into_n(duration + 1, ctx);
        vector::push_back(&mut vector_day_reward, sum_reward);

        // 把奖励vector存入奖池
        let mut rewardpool_number_coin_table = table::new<u64, vector<Coin<COIN>>>(ctx);
        table::add<u64, vector<Coin<COIN>>>(&mut rewardpool_number_coin_table, stake_number, vector_day_reward);
        table::add<address, Table<u64, vector<Coin<COIN>>>>(&mut rewardpool_info.rewardpool_address_table, staker, rewardpool_number_coin_table);
    }

    // 管理员更新质押平台信息
    public entry fun update_staking_platform<COIN>(
        staking_platform: &mut StakingPlatform<COIN>,
        annual_rate: u64,
        _stakeplatform_cap: &Publisher,
        ctx: &mut TxContext
    ) {
        staking_platform.annual_rate = annual_rate;

        event::emit(UpdateStakePlatformEvent {
            event_counter: staking_platform.update_platform_event_counter,
            admin: ctx.sender(),
            annual_rate,
            stakingplatform_id: object::uid_to_inner(&staking_platform.id),
        });

        staking_platform.update_platform_event_counter = staking_platform.update_platform_event_counter + 1;
    }

    // 质押代币
    public entry fun stake<COIN>(
        stake_amount: u64,
        duration: u64,
        mut stake_coin: Coin<COIN>,
        current_time: &clock::Clock,
        staking_platform: &mut StakingPlatform<COIN>,
        ctx: &mut TxContext
    ) {
        // 传入代币数量要大于质押数量
        assert!(stake_coin.value() >= stake_amount, EStakeCoinAmountInsufficient);
        // 开始时间 结束时间
        let start_timestamp = clock::timestamp_ms(current_time);
        let end_timestamp = start_timestamp + duration * 24 * 60 * 60 * 1000;

        // 获取今天10点的时间戳
        let ten_am_timestamp = get_today_ten_am_timestamp(current_time);
        // 在今天10点前质押，初始提取时间置今天10点
        // 在今天10点后质押，初始提取时间置明天天10点
        let last_withdraw_time = if (ten_am_timestamp >= start_timestamp) {
            ten_am_timestamp
        } else {
            ten_am_timestamp + 24 * 60 * 60 * 1000
        };

        // 质押信息
        let mut stake_info = StakeInfo {
            id: object::new(ctx),
            staker: ctx.sender(),
            stake_amount,
            annual_rate: staking_platform.annual_rate,
            start_time: start_timestamp,
            duration,
            end_time: end_timestamp,
            last_withdraw_time,
            stake_status: true,
        };
        // 质押代币直接锁仓 存入质押信息 ? 质押代币直接转给奖池管理员
        // 质押代币直接转给奖池管理员 可以在调用unstake后，后端用奖池管理员账户去归还质押的代币
        if (stake_coin.value() > stake_amount) {
            // 留下质押数量的代币，其余代币返还给质押者
            let stake_amount_coin = stake_coin.split(stake_amount, ctx);
            transfer::public_transfer(stake_coin, ctx.sender());
            // transfer::public_transfer(stake_amount_coin, staking_platform.admin); // reward_pool.admin
            field::add(&mut stake_info.id, b"stake_coin", stake_amount_coin);
        } else {
            // transfer::public_transfer(stake_coin, staking_platform.admin); // reward_pool.admin
            field::add(&mut stake_info.id, b"stake_coin", stake_coin);
        };

        // 质押信息放入质押编号_信息表 Table<质押编号: 质押信息>
        let contains = table::contains<address, Table<u64, StakeInfo>>(&staking_platform.stake_address_record_table, ctx.sender());
        let (address_stake_counter, stake_number_info_table) = if (contains) {
            // 取出当前账户质押编号并+1
            let mut stake_number_info_table = table::remove<address, Table<u64, StakeInfo>>(&mut staking_platform.stake_address_record_table, ctx.sender());
            let address_stake_counter = stake_number_info_table.length();
            table::add(&mut stake_number_info_table, address_stake_counter, stake_info);
            (address_stake_counter, stake_number_info_table)
        } else {
            let mut stake_number_info_table = table::new<u64, StakeInfo>(ctx);
            let address_stake_counter = 0;
            table::add(&mut stake_number_info_table, address_stake_counter, stake_info);
            (address_stake_counter, stake_number_info_table)
        };
        table::add<address, Table<u64, StakeInfo>>(&mut staking_platform.stake_address_record_table, ctx.sender(), stake_number_info_table);

        // 质押编号_信息表放入质押地址_记录表 <质押者地址: Table<质押编号：质押信息>>
        // 计数器
        staking_platform.total_stake_record_count = staking_platform.total_stake_record_count + 1;
        // 暂时定义为质押人次(不去重)而不是质押人数(去重)
        staking_platform.total_staker_count = staking_platform.total_staker_count + 1;
        staking_platform.total_staked_amount = staking_platform.total_staked_amount + stake_amount;

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
            duration,
            end_time: end_timestamp,
            address_stake_counter,
            // 计数器 总共质押次数，总共质押人数，总共质押金额
            total_stake_record_count: staking_platform.total_stake_record_count,
            total_staker_count: staking_platform.total_staker_count,
            total_staked_amount: staking_platform.total_staked_amount,
        });

        staking_platform.stake_event_counter = staking_platform.stake_event_counter + 1;
    }

    // 解质押代币 质押到期后随时可以解除
    public entry fun un_stake<COIN>(
        address_stake_counter: u64,
        current_time: &clock::Clock,
        staking_platform: &mut StakingPlatform<COIN>,
        ctx: &mut TxContext
    ) {
        // 质押没到期不可解除
        let current_timestamp = clock::timestamp_ms(current_time);
        let mut stake_number_info_table = table::remove<address, Table<u64, StakeInfo>>(&mut staking_platform.stake_address_record_table, ctx.sender());
        let mut stake_info = table::remove<u64, StakeInfo>(&mut stake_number_info_table, address_stake_counter);
        let end_timestamp = stake_info.end_time;
        assert!(current_timestamp >= end_timestamp, EStakeTimeNotReached);

        // 返还质押代币
        let stake_coin = field::remove<vector<u8>,Coin<COIN>>(&mut stake_info.id, b"stake_coin");
        transfer::public_transfer(stake_coin, ctx.sender());

        // 更新质押状态
        stake_info.stake_status = false;
        let stake_amount = stake_info.stake_amount;
        table::add(&mut stake_number_info_table, address_stake_counter, stake_info);
        table::add<address, Table<u64, StakeInfo>>(&mut staking_platform.stake_address_record_table, ctx.sender(), stake_number_info_table);

        // 触发解质押事件
        event::emit(UnstakeEvent {
            unstake_event_counter: staking_platform.unstake_event_counter,
            unstaker: ctx.sender(),
            unstake_amount: stake_amount,
            unstake_time: current_timestamp,
            stake_id: address_stake_counter,
        });

        staking_platform.unstake_event_counter = staking_platform.unstake_event_counter + 1;
    }

    // 用户提取奖励 只要池子有钱就可以提取奖励
    public entry fun withdraw_reward<COIN>(
        stake_number: u64,
        current_time: &clock::Clock,
        rewardpool_info: &mut RewardPoolInfo<COIN>,
        staking_platform: &mut StakingPlatform<COIN>,
        ctx: &mut TxContext
    ) {
        // 要求与上次提取时间满1整天才能提取
        let stake_address_record_table = table::borrow_mut<address, Table<u64, StakeInfo>>(&mut staking_platform.stake_address_record_table, ctx.sender());
        let stake_number_info_table = table::borrow_mut<u64, StakeInfo>(stake_address_record_table, stake_number);
        let current_duration = cal_days_between(current_time.timestamp_ms(), stake_number_info_table.last_withdraw_time);
        assert!(current_duration >= 1, EStakingPeriodInsufficient);

        // 获取今天10点的时间戳
        let ten_am_timestamp = get_today_ten_am_timestamp(current_time);

        // 更新本次提取时间
        stake_number_info_table.last_withdraw_time = ten_am_timestamp;

        // 从奖池中取出staker的vector<day_reward>
        let mut rewardpool_number_coin_table = table::remove(&mut rewardpool_info.rewardpool_address_table, ctx.sender());
        let mut vector_day_reward: vector<Coin<COIN>> = table::remove(&mut rewardpool_number_coin_table, stake_number);

        // 取出vector_day_reward的第days份day_reward
        let mut extractable_reward = vector::pop_back(&mut vector_day_reward);
        let mut i = current_duration;
        while (i < stake_number_info_table.duration) {
            let day_reward = vector::pop_back(&mut vector_day_reward);
            extractable_reward.join(day_reward);
            i = i + 1;
        };

        // 未使用的reward打回奖池
        table::add(&mut rewardpool_number_coin_table, stake_number, vector_day_reward);
        table::add(&mut rewardpool_info.rewardpool_address_table, ctx.sender(), rewardpool_number_coin_table);

        // 把可提取的奖励打给用户
        let withdraw_amount = extractable_reward.value();
        transfer::public_transfer(extractable_reward, ctx.sender());

        let stake_number_info_table = table::borrow<address, Table<u64, StakeInfo>>(&staking_platform.stake_address_record_table, ctx.sender());
        let address_stake_counter = stake_number_info_table.length();

        event::emit(WithdrawRewardEvent {
            event_counter: staking_platform.withdraw_reward_event_counter,
            withdarwer: ctx.sender(),
            withdraw_amount,
            withdraw_time: current_time.timestamp_ms(),
            stakerecord_id: address_stake_counter,
        });

        staking_platform.withdraw_reward_event_counter = staking_platform.withdraw_reward_event_counter + 1;
    }

    fun get_today_ten_am_timestamp(current_time: &clock::Clock): u64 {
        // 获取当前时间戳（毫秒）
        let current_day_timestamp = current_time.timestamp_ms();
        // 计算今天0点的时间戳
        let today_start_timestamp = (current_day_timestamp / (24 * 60 * 60 * 1000)) * (24 * 60 * 60 * 1000);
        // 计算今天10点的时间戳
        let ten_am_timestamp = today_start_timestamp + (10 * 60 * 60 * 1000);

        ten_am_timestamp
    }

    #[test]
    fun test_create_stake() {
        use std::debug;
        use mgo::test_scenario::{Self, next_tx, ctx};

        let admin = @0xA;
        let mut scenario = test_scenario::begin(admin);

        init(STAKING_PLATFORM {}, ctx(&mut scenario));
        // 新的场景 admin是新的sender
        next_tx(&mut scenario, admin);
        let publisher = test_scenario::take_from_address<Publisher>(&scenario, admin);
        // 创建质押平台
        test_scenario::return_to_address<Publisher>(admin, publisher);

        // let staking_platform = test_scenario::take_from_address<StakingPlatform<USDT>>(&scenario, admin);

        // 怎么模拟代币 怎么模拟时间

        // 质押代币
        // stake<USDT>(9999, 7776000000, usdt, 0x6, &mut staking_platform, ctx(&mut scenario));
        // test_scenario::return_to_address<StakingPlatform<USDT>>(admin, staking_platform);

        scenario.end();
    }
}