#!/bin/zsh
# 包
PACKAGE_ID=0x500ab5fb293f61fe4c29e746a28f19ca65c3a22dbfd4d2c0c89378137d24d809
StakePlatform_USDT_ID=0x60d3ef493cc292bc5fe3d400c7ae8d1a4eff5c10829a8180cf607c8c03b0d3fc
StakePlatform_MGO_ID=0x6bef69bbd4328ca4a975d05e7926d7257a2e6e6f9eb665f2f0f8cf8fb0cc374d
Stake_Publisher=0xeb2cf1410bb285fa4f994629967b1b9505981fc5c8db6a4765a408a9d55e7fc8
Pool_Publisher=0xf47cf2f0b09753b5905ec72c9c1eb657e052fd4f620dfd3835f4ce68006566ea
MGO_TREASURY_CAP=0x93ccabd0a1cf6fa1ce5098f42243acc2fcf8bbe62bdf36f3fb4b57450c094192
USDT_TREASURY_CAP=0x43e20636e0ee9ac87049427a6965ffc20376fe366a1733594adef2e12ab1225b
Pool_ID=0xa9f7ac1643fd364f732cdee37b894717ca6127d4530d5ef07085f3f318f19d93
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
SATKE_AMOUT=10000
DURATION=10

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
call_function_stake() {
    echo "Calling function $CREATE_COLLECTION with generic $GENERIC_COIN..."
    mgo client call --package $PACKAGE_ID --module $MODULE_STAKE --function $STAKE \
    --gas-budget 100000000 --type-args $USDT_TYPE --args $SATKE_AMOUT $DURATION \
    $USDT_ID $CURRENT_TIME $StakePlatform_ID
}
call_function_create_stakeplatform() {
    echo "Calling function $CREATE_COLLECTION with generic $GENERIC_COIN..."
    mgo client call --package $PACKAGE_ID --module $MODULE_STAKE --function $CREATE_STAKEPLATFORM \
    --gas-budget 100000000 --type-args $USDT_TYPE --args $ANNUAL_RATE $Stake_Publisher
}
# 函数：调用 MGO Move 包中的函数
call_function_create_rewardpool() {
    echo "Calling function $CREATE_COLLECTION with generic $GENERIC_COIN..."
    mgo client call --package $PACKAGE_ID --module $MODULE_POOL --function $CREATE_POOL \
    --gas-budget 100000000 --type-args $USDT_TYPE --args $Pool_Publisher
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
    update_collection)
        call_function_update_collection
        ;;
    switch_address)
        client_switch_address
        ;;
    *)
        echo "Usage: $0 {deploy|mint_usdt|update_collection|mint_nft|create_market|update_market|list_nft|delist_nft|buy_nft|take_profits|switch_address}"
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
