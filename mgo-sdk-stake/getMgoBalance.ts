import { getFullnodeUrl, MgoClient } from "@mgonetwork/mango.js/client";

const client: MgoClient = new MgoClient({
  url: getFullnodeUrl("devnet"),
});

// Manually calling unsupported rpc methods
const committeeInfo = await client.call("<PRC_METHOD_NAME>", []);

const reward = ethers.utils.parseEther(rewardAmount);
const taskId = contract.deployTask(title, reward);
console.log("taskID :", taskId);
