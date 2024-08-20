import { getFaucetHost, requestSuiFromFaucetV0 } from "@mysten/sui/faucet";

const RECIPIENT_ADDRESS =
  "0x2108b3f829cc7ab2fd740da1bd1d229938cde38b305e9cef7cf17c03808302d9";

await requestSuiFromFaucetV0({
  host: getFaucetHost("testnet"),
  recipient: RECIPIENT_ADDRESS,
});
