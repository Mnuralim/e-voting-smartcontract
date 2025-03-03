import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition";
import dotenv from "dotenv";
import "@openzeppelin/hardhat-upgrades";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    hardhat: {},
    arbitrum_sepolia: {
      url: "https://arbitrum-sepolia-rpc.publicnode.com",
      accounts: [
        `0x${process.env.PRIVATE_KEY}`,
      ],
    },
  },
  defaultNetwork: "arbitrum_sepolia",
};

export default config;
