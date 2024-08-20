import {
  getFullnodeUrl,
  SuiClient,
  SuiHTTPTransport,
} from "@mysten/sui/client";

const client = new SuiClient({
  transport: new SuiHTTPTransport({
    url: "https://my-custom-node.com/rpc",
    websocket: {
      reconnectTimeout: 1000,
      url: "https://my-custom-node.com/websockets",
    },
    rpc: {
      headers: {
        "x-custom-header": "custom value",
      },
    },
  }),
});

console.log({ client });

const page1 = await client.getCheckpoints({
  limit: 10,
});

const page2 =
  page1.hasNextPage &&
  client.getCheckpoints({
    cursor: page1.nextCursor,
    limit: 10,
  });
