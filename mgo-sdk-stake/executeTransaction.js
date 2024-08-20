const tx = new Transaction();

// add transaction data to tx...

const { bytes, signature } = tx.sign({ client, signer: keypair });

const result = await client.executeTransactionBlock({
  transactionBlock: bytes,
  signature,
  requestType: "WaitForLocalExecution",
  options: {
    showEffects: true,
  },
});

const signTx = new Transaction();
// add transaction data to tx

// 直接返回交易信息
const signResult = await client.signAndExecuteTransaction({
  transaction: tx,
  signer: keypair,
  requestType: "WaitForLocalExecution",
  options: {
    showEffects: true,
  },
});

const waitTx = new Transaction();

const waitResult = await client.signAndExecuteTransaction({
  transaction: tx,
  signer: keypair,
});

// 通过digest=hash来查询交易信息
const transaction = await client.waitForTransaction({
  digest: result.digest,
  options: {
    showEffects: true,
  },
});
