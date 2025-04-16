import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition";
import dotenv from "dotenv";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-verify";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    hardhat: { loggingEnabled: true },
    arbitrum_sepolia: {
      url: "https://arbitrum-sepolia-rpc.publicnode.com",
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
    sepolia: {
      url: "https://ethereum-sepolia-rpc.publicnode.com",
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
    "base-sepolia": {
      chainId: 84532,
      url: "https://base-sepolia-rpc.publicnode.com",
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
    base: {
      chainId: 8453,
      url: "https://base-rpc.publicnode.com",
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
  },
  sourcify: {
    enabled: true,
  },
  etherscan: {
    enabled: true,
    apiKey: {
      "base-sepolia": process.env.BASE_API_KEY!,
    },
    customChains: [
      // {
      //   network: "base",
      //   chainId: 8453,
      //   urls: {
      //     apiURL: "https://api.basescan.org/api",
      //     browserURL: "https://basescan.org",
      //   },
      // },
      {
        network: "base-sepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://base-sepolia.blockscout.com/api",
          browserURL: "https://base-sepolia.blockscout.com/",
        },
      },
    ],
  },
  defaultNetwork: "arbitrum_sepolia",
};

export default config;
