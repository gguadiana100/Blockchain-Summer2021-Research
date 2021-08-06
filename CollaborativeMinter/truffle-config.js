module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    rinkeby: {
      host: "127.0.0.1",
      port: 8545,
      from: "0xC4FB3Df2824AD424EbEF302970d67151051B5500",
      network_id: 4,
      gas: 4612388 // Gas limit used for deploys
    },
  },
  contracts_directory: './src/contracts/',
  contracts_build_directory: './src/build/',
  migrations_directory: './src/migrations/',
  compilers: {
    solc: {
      version: "^0.8.0",
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}
