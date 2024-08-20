import * as fs from "fs";
import * as dotenv from "dotenv";
dotenv.config();
import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

// use getFullnodeUrl to define Devnet RPC location
const rpcUrl = getFullnodeUrl("testnet");

// create a client connected to devnet
const client = new SuiClient({ url: rpcUrl });

const privateKey = process.env.PRIVATE_KEY;
const keypair = Ed25519Keypair.fromSecretKey(privateKey);

// 加载 Move 包（通常是 `build/` 目录下的字节码）
const modules = fs.readFileSync(
  "/Users/wyz/Downloads/train/blockchain_train/move_train/mango_train/defi/stake/build/stake/bytecode_modules/usdt.mv"
);
``;
// 构建并发布 Move 包的交易
async function publishPackage() {
  const tx = new Transaction();

  // 发布 Move 模块
  tx.publish({
    modules: [modules],
    dependencies: [], // 如果有依赖项，请提供相应的模块ID
  });

  // 执行交易
  const result = await client.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
    requestType: "WaitForLocalExecution",
    options: {
      showEffects: true,
    },
  });

  console.log("Publish result:", result);
}

// // 初始化 USDT 货币
// async function initUSDT() {
//   const tx = new Transaction();

//   // 调用 `init` 函数
//   tx.moveCall({
//     target: "your_address::stake::init", // 使用发布后的包地址替换 your_address
//     arguments: [tx.object({}), tx.gas],
//   });

//   // 执行交易
//   const result = await signer.signAndExecuteTransaction({ transaction: tx });

//   console.log("Init USDT result:", result);
// }

// 执行发布并初始化
async function main() {
  await publishPackage();
}

main().catch(console.error);
