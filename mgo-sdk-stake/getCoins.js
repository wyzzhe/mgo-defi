import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";

const MY_ADDRESS =
  "0x2108b3f829cc7ab2fd740da1bd1d229938cde38b305e9cef7cf17c03808302d9";

// use getFullnodeUrl to define Devnet RPC location
const rpcUrl = getFullnodeUrl("testnet");

// create a client connected to devnet
const client = new SuiClient({ url: rpcUrl });

// get coins owned by an address
// replace <OWNER_ADDRESS> with actual address in the form of 0x123...
const coins = await client.getCoins({
  owner: MY_ADDRESS,
});

console.log({ coins });
