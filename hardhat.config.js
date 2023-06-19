require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-etherscan")
require("hardhat-deploy")
require("solidity-coverage")
require("hardhat-gas-reporter")
require("hardhat-contract-sizer")
require("dotenv").config()

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x"
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY
const REPORT_GAS = process.env.REPORT_GAS || false

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 31337,
        },
        localhost: {
            chainId: 31337,
        },

        polygonMumbai: {
            url: "https://rpc.ankr.com/polygon_mumbai",
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
            saveDeployments: true,
            chainId: 80001,
        },
        scroll: {
            url: "https://scroll-testnet.blockpi.network/v1/rpc/public",
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
            saveDeployments: true,
            chainId: 534353,
        },

        avalancheFujiTestnet: {
            url: "https://rpc.ankr.com/avalanche_fuji",
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
            saveDeployments: true,
            chainId: 43113,
        },
        arbitrumGoerli: {
            url: "https://endpoints.omniatech.io/v1/arbitrum/goerli/public",
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
            saveDeployments: true,
            chainId: 421613,
        },
        baseTestnet: {
            url: "https://goerli.base.org",
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
            saveDeployments: true,
            chainId: 84531,
        },
        mantleTestnet: {
            url: "https://rpc.testnet.mantle.xyz",
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
            saveDeployments: true,
            chainId: 5001,
        },
    },
    etherscan: {
        // yarn hardhat verify --network <NETWORK> <CONTRACT_ADDRESS> <CONSTRUCTOR_PARAMETERS>
        apiKey: {
            goerli: ETHERSCAN_API_KEY,
            arbitrumGoerli: ETHERSCAN_API_KEY,
            polygonMumbai: POLYGONSCAN_API_KEY,
            scroll: ETHERSCAN_API_KEY,
            mantleTestnet: ETHERSCAN_API_KEY,
            baseTestnet: ETHERSCAN_API_KEY,
            avalancheFujiTestnet: ETHERSCAN_API_KEY,
        },
        customChains: [
            {
                network: "scroll",
                chainId: 534353,
                urls: {
                    apiURL: "https://blockscout.scroll.io/api",
                    browserURL: "https://blockscout.scroll.io/",
                },
            },
            {
                network: "mantleTestnet",
                chainId: 5001,
                urls: {
                    apiURL: "https://explorer.testnet.mantle.xyz/api",
                    browserURL: "https://explorer.testnet.mantle.xyz/",
                },
            },
            {
                network: "baseTestnet",
                chainId: 84531,
                urls: {
                    apiURL: "https://goerli.basescan.org/api",
                    browserURL: "https://goerli.basescan.org/",
                },
            },
        ],
    },
    gasReporter: {
        enabled: REPORT_GAS,
        currency: "USD",
        outputFile: "gas-report.txt",
        noColors: true,
        coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    },
    contractSizer: {
        runOnCompile: false,
        only: ["EntryPoint"],
    },
    namedAccounts: {
        deployer: {
            default: 0, // here this will by default take the first account as deployer
            1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
        },
    },
    solidity: {
        compilers: [
            {
                version: "0.8.13",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1000,
                    },
                },
            },
        ],
    },
    allowUnlimitedContractSize: true,
    mocha: {
        timeout: 500000, // 500 seconds max for running tests
    },
}
