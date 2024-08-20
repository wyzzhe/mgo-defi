import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";

const client = new SuiClient({ url: getFullnodeUrl("testnet") });

// asynchronously call suix_getCommitteeInfo
const committeeInfo = await client.call("suix_getCommitteeInfo", []);

console.log({ committeeInfo });
