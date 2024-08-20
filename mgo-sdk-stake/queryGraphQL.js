import { SuiGraphQLClient } from "@mysten/sui/graphql";
import { graphql } from "@mysten/sui/graphql/schemas/2024.4";

const gqlClient = new SuiGraphQLClient({
  url: "https://sui-testnet.mystenlabs.com/graphql",
});

const chainIdentifierQuery = graphql(`
  query {
    chainIdentifier
  }
`);

async function getChainIdentifier() {
  const result = await gqlClient.query({
    query: chainIdentifierQuery,
  });

  console.log({ result });

  return result.data?.chainIdentifier;
}

getChainIdentifier();

const getSuinsName = graphql(`
  query getSuiName($address: SuiAddress!) {
    address(address: $address) {
      defaultSuinsName
    }
  }
`);

async function getDefaultSuinsName(address) {
  const result = await gqlClient.query({
    query: getSuinsName,
    variables: {
      address,
    },
  });

  console.log(JSON.stringify(result, null, 2));

  return result.data?.address?.defaultSuinsName;
}

const ADDRESS =
  "0x2108b3f829cc7ab2fd740da1bd1d229938cde38b305e9cef7cf17c03808302d9";

getDefaultSuinsName(ADDRESS);
