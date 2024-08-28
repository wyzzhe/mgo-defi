#!/bin/zsh
# 包
PACKAGE_ID=0xde0f8e948803b99562a63a32fec6433f56e69aee290d364abc6d62cac0fdcc06
PlatformCounter=0xe9f54bed4b758f64f31bcf5d26b3d6f662cdd17fe4cd9641b7296b3ea60084ee
Stake_Publisher=0x86728cc18b6c7346129e01b61f25e132062e239eecb6fb16d87c17891dc750b8
Pool_Publisher=0x92208f4d787db2796800d7f2c35015d47eb99c9ee0814fd8936b3aa449765e7b
StakePlatform_USDT_ID=0x611536f58ee6eea34db839bb70fceb555ddd49a74f043dfa77130a0b71b1b684
Pool_USDT_ID=0xad47435eb881f7b2b6dec214d42e1c29d2385c13c7f7a990519031e3cd688574
StakeInfo=0xe732ca6c7d5b81c357a56df7e869fb3af204e23873242cbbe138f7039fefb679
StakePlatform_MGO_ID=0xaef8ebb9079b8a00eb3722a9c24371ce90c21d6caa57ad24a438ce06a682c058
Pool_MGO_ID=0x58c8e076be65fc5eb7cc866857ca80be825be2ff39f14f9a2dd72f42ed3c9a63
Upgrade_Cap=0xfb4e2511390eb3571abe07723b2ca3a58d9bd1a41406cb55f01e3b0b0343b714
b=0x0de63e16b3964332e49e7ff61e5c90700091cef29d76c825cff9d0d6722b711c
c=0x0de63e16b3964332e49e7ff61e5c90700091cef29d76c825cff9d0d6722b711c
MGO_TREASURY_CAP=0x93ccabd0a1cf6fa1ce5098f42243acc2fcf8bbe62bdf36f3fb4b57450c094192
USDT_TREASURY_CAP=0x43e20636e0ee9ac87049427a6965ffc20376fe366a1733594adef2e12ab1225b

# 账户别名
ADDRESS1=unruffled-amethyst
ADDRESS2=heuristic-chrysoberyl
ADDRESS3=compassionate-labradorite
ADDRESS3_ID=0xad4b025a268fa1314207581e9321716662bf3928bb02b095fded8e912e6f865e
ADDRESS4_ID=0x6d5ae691047b8e55cb3fc84da59651c5bae57d2970087038c196ed501e00697b
# 切换到此账户地址
CURRENT_ADDRESS=$ADDRESS1
USDT_ID=0xaa2fd6dc3763e04d9078de8d4434bcbb4dda5ddb22e29808f2ad78355da0e93f
MGO_ID=0xccccd65823a60b563d44a821eb2d7374d06f94d7bf4867c29d46adcd965d8107
MODULE_USDT=usdt
MODULE_MGO=mgo
MODULE_STAKE=staking_platform
MODULE_POOL=pool
MINT_USDT=mint
MINT_MGO=mint
CREATE_STAKEPLATFORM=create_staking_platform
UPDATE_STAKEPLATFORM=update_staking_platform
CREATE_POOL=create_reward_pool
STAKE=stake
# 泛型
COIN_TYPE="0x2::mgo::MGO"
USDT_TYPE=0x85d085a213a0421d64c5e82a940cfdb8ef703137fff4c2b15528c3001737bf8b::usdt::USDT
MGO_TYPE=0x85d085a213a0421d64c5e82a940cfdb8ef703137fff4c2b15528c3001737bf8b::mgo::MGO
# 参数
SELL_END_TIME=1753257897748
CURRENT_TIME=0x6
FEE_RATE=100 # 相当于1.00%
ROYALTY_RATE=100
AMOUNT=1000000000
ANNUAL_RATE=500
SATKE_AMOUT=1000000
DURATION_DAYS=10
DURATION_MS=864000000
PRE_REWARD=pre_reward_pool
STAKER=0x6d5ae691047b8e55cb3fc84da59651c5bae57d2970087038c196ed501e00697b
STAKE_NUMBER=1
#$DURATION

# 代币精度6位
# 1=1000000
# 1000=1000000000

# 函数：部署 MGO Move 包
deploy_package() {
    echo "Deploying MGO Move package..."
    mgo client publish ./ --gas-budget 100000000 --skip-fetch-latest-git-deps
}

# 函数：调用 MGO Move 包中的函数
call_function_pre_reward() {
    echo "Calling function $CREATE_COLLECTION with generic $GENERIC_COIN..."
    mgo client call --package $PACKAGE_ID --module $MODULE_STAKE --function $PRE_REWARD \
    --gas-budget 100000000 --type-args $USDT_TYPE --args $STAKER $SATKE_AMOUT $DURATION_DAYS \
    $ANNUAL_RATE $STAKE_NUMBER $USDT_ID $Pool_USDT_ID
}
call_function_stake() {
    echo "Calling function $CREATE_COLLECTION with generic $GENERIC_COIN..."
    mgo client call --package $PACKAGE_ID --module $MODULE_STAKE --function $STAKE \
    --gas-budget 100000000 --type-args $USDT_TYPE --args $SATKE_AMOUT $DURATION_DAYS \
    $USDT_ID $CURRENT_TIME $StakePlatform_USDT_ID
}
call_function_create_stakeplatform() {
    echo "Calling function $CREATE_COLLECTION with generic $GENERIC_COIN..."
    mgo client call --package $PACKAGE_ID --module $MODULE_STAKE --function $CREATE_STAKEPLATFORM \
    --gas-budget 100000000 --type-args $USDT_TYPE --args $ANNUAL_RATE $PlatformCounter $Stake_Publisher
}
# 函数：调用 MGO Move 包中的函数
call_function_create_rewardpool() {
    echo "Calling function $CREATE_COLLECTION with generic $GENERIC_COIN..."
    mgo client call --package $PACKAGE_ID --module $MODULE_STAKE --function $CREATE_POOL \
    --gas-budget 100000000 --type-args $USDT_TYPE --args $Pool_Publisher
}
call_function_update_stakeplatform() {
    echo "Calling function $CREATE_COLLECTION with generic $GENERIC_COIN..."
    mgo client call --package $PACKAGE_ID --module $MODULE_STAKE --function $UPDATE_STAKEPLATFORM \
    --gas-budget 100000000 --type-args $USDT_TYPE --args $StakePlatform_USDT_ID $ANNUAL_RATE $Stake_Publisher
}
call_function_mint_usdt() {
    echo "Calling function $CREATE_COLLECTION with generic $GENERIC_COIN..."
    mgo client call --package $PACKAGE_ID --module $MODULE_USDT --function $MINT_USDT \
    --gas-budget 100000000 --args $USDT_TREASURY_CAP $AMOUNT $ADDRESS4_ID
}
call_function_mint_mgo() {
    echo "Calling function $CREATE_COLLECTION with generic $GENERIC_COIN..."
    mgo client call --package $PACKAGE_ID --module $MODULE_MGO --function $MINT_MGO \
    --gas-budget 100000000 --args $MGO_TREASURY_CAP $AMOUNT $ADDRESS4_ID
}
call_function_update_collection() {
    echo "Calling function $UPDATE_COLLECTION with generic $GENERIC_COIN..."
    mgo client call --package $PACKAGE_ID --module $MODULE_COLLECTION --function $UPDATE_COLLECTION \
    --gas-budget 100000000 --type-args $GENERIC_COIN --args $NAME1 "this are dragons" \
    $COLLECTION_URL $NFT_URL $MINT_END_TIME $MINT_PRICE $COLLCTION_CAP
}
client_switch_address() {
    if [ "$CURRENT_ADDRESS" == "$ADDRESS1" ]; then
        CURRENT_ADDRESS=$ADDRESS2
    else
        CURRENT_ADDRESS=$ADDRESS1
    fi
    echo "Switch address to $CURRENT_ADDRESS"
    mgo client switch --address $CURRENT_ADDRESS
}
# 执行命令
# 检查参数并执行相应的函数
case "$1" in
    deploy)
        deploy_package
        ;;
    pre_reward)
        call_function_pre_reward
        ;;
    mint_usdt)
        call_function_mint_usdt
        ;;
    mint_mgo)
        call_function_mint_mgo
        ;;
    stake)
        call_function_stake
        ;;
    create_rewardpool)
        call_function_create_rewardpool
        ;;
    create_stakeplatform)
        call_function_create_stakeplatform
        ;;
    update_stakeplatform)
        call_function_update_stakeplatform
        ;;
    switch_address)
        client_switch_address
        ;;
    *)
        echo "Usage: $0 {deploy|pre_reward|mint_usdt|create_stakeplatform|create_rewardpool|stake|update_stakeplatform|switch_address}"
        exit 1
        ;;
esac
# 运行脚本
# sh script.sh buy_nft
# 转账mgo代币 可以直接在一个mgo的gas币对象上转出一定数额的mgo币
# mgo client transfer-mgo --to 0xad4b025a268fa1314207581e9321716662bf3928bb02b095fded8e912e6f865e --mgo-coin-object-id 0x4262a695458ecc0fab0a28c279b42cbf6bf0965154cc27f5fbe596a4149b8c91 --gas-budget 100000000 --amount 1000
# 分币
# mgo client split-coin --coin-id 0x402ca1c57085c6cc5c0d75ab47b0a07a9631a185c1136ee9514e1a1e54b84acc --gas-budget 30000000 --amounts 10000
# 切换账号
# mgo client switch --address heuristic-chrysoberyl
# 查看gas
# mgo client gas
# mgo move build --skip-fetch-latest-git-deps
# unruffled-amethyst 0x1299f92c597eb13c9a85a1a3a7339925c92c9763b4931be64e6410f57e14c871
# heuristic-chrysoberyl 0xad4b025a268fa1314207581e9321716662bf3928bb02b095fded8e912e6f865e

#mgo client merge-coin --primary-coin 0xcbb17dbfb36ad8c46390cf341cc3bcc3812d8918d0951bf1c5d9f38306829e60 --coin-to-merge 0xc6e71c65c76d33c5ec1f464651590593dc02e98a8bea7d7692cc8e4802360240 --gas-budget 100000000
#sh script.sh deploy
#sh script.sh mint_usdt
