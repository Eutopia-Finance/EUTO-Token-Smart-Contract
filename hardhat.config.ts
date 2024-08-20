import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-verify";
import dotenv from "dotenv";

dotenv.config();

const SEPOLIA_PRIVATE_KEY = process.env.SEPOLIA_PRIVATE_KEY || "";
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "";
const SEPOLIA_INFURA_ENDPOINT = process.env.SEPOLIA_INFURA_ENDPOINT || "";

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";

const ETHEREUM_PRIVATE_KEY = process.env.ETHEREUM_PRIVATE_KEY || "";
const ETHEREUM_RPC_URL = process.env.ETHEREUM_RPC_URL || "";
const ETHEREUM_INFURA_ENDPOINT = process.env.ETHEREUM_INFURA_ENDPOINT || "";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 1337,
      forking: {
        url: SEPOLIA_INFURA_ENDPOINT,
      },
    },
    sepolia: {
      url: SEPOLIA_RPC_URL,
      chainId: 11155111,
      accounts: [SEPOLIA_PRIVATE_KEY],
    },
    ethereum: {
      url: 'https://eth.merkle.io',
      chainId: 1,
      accounts: [ETHEREUM_PRIVATE_KEY]
    },
  },
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_API_KEY,// //
      mainnet: ETHERSCAN_API_KEY,// //
      // // sepolia: "sepolia",
      // // ethereum: "ethereum",
    },
    // // customChains: [
    // //   {
    // //     network: "sepolia",
    // //     chainId: 11155111,
    // //     urls: {
    // //       apiURL: "https://api.routescan.io/v2/network/testnet/evm/11155111/etherscan",
    // //       browserURL: "https://11155111.testnet.routescan.io/"
    // //     }
    // //   },
    // //   {
    // //     network: "ethereum",
    // //     chainId: 1,
    // //     urls: {
    // //       apiURL: "https://api.routescan.io/v2/network/mainnet/evm/1/etherscan",
    // //       browserURL: "https://1.routescan.io"
    // //     }
    // //   }
    // // ]
  },
  mocha: {
    timeout: 600000
  }
};

export default config;
