const HDWalletProvider = require("@truffle/hdwallet-provider");

let rinkebyProviderURL = "https://rinkeby.infura.io/v3/" + process.env.WEB3_INFURA_PROJECT_ID;
let privateKey = process.env.PRIVATE_KEY;

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    rinkeby: {
      provider: () => {
        return new HDWalletProvider(privateKey, rinkebyProviderURL);
      },
      network_id: 4,
      networkCheckTimeout: 1000000,
      timeoutBlocks: 200
    },
  },
  contracts_directory: './src/contracts/',
  contracts_build_directory: './src/build/',
  migrations_directory: './src/migrations/',
  compilers: {
    solc: {
      version: "^0.8.6",
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}
