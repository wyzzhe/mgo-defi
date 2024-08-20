import { Transaction } from "@mysten/sui/transactions";
import {
  SuiClient,
  SuiHTTPTransport,
  getFullnodeUrl,
} from "@mysten/sui/client";

const ADDRESS =
  "0x2108b3f829cc7ab2fd740da1bd1d229938cde38b305e9cef7cf17c03808302d9";

// 创建一个新的 Sui 客户端，指向测试网
const client = new SuiClient({
  transport: new SuiHTTPTransport({
    url: getFullnodeUrl("testnet"), // 使用测试网 URL
  }),
});

// 使用SuiClient实例查询账户余额
async function getBalanceAndDisplay() {
  try {
    // 使用 await 等待 getBalance 完成
    const result = await client.getCoins({
      owner: ADDRESS,
      coinType: "0x2::sui::SUI",
    });

    // 打印详细结果
    console.log("Balance result:", result);
  } catch (error) {
    console.error("Error fetching balance:", error);
  }
}

// 调用异步函数
getBalanceAndDisplay();

// 构建交易块
const tx = new Transaction();
client.signAndExecuteTransaction({ signer: keypair, transaction: tx });
