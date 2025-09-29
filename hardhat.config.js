require("@nomicfoundation/hardhat-toolbox");
require("@chainlink/env-enc").config()
// require("./tasks/deploy-nft.js")
require("./tasks")
require("hardhat-deploy")
require("@nomicfoundation/hardhat-ethers");
require("hardhat-deploy-ethers");


const SEPOLIA_URL = process.env.SEPOLIA_URL
const PRIVATE_KEY = process.env.PRIVATE_KEY
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: "0.8.28",
    defaultNetwork: "hardhat",//默认hardhat
    mocha: {
        timeout: 300000
    },
    networks: {
        sepolia: {
            url: SEPOLIA_URL,
            accounts: [PRIVATE_KEY,],
            chainId: 11155111,
        }
    },
    etherscan: {
        apiKey: {
            sepolia: ETHERSCAN_API_KEY
        }
    },
    sourcify: {
        // Disabled by default
        // Doesn't need an API key
        enabled: true
    },
    namedAccounts: {
        firstAccount: {
            default: 0
        },
        secondAccount: {
            default: 1
        }
    },
    gasReporter: {
        enabled: true
    }

};
