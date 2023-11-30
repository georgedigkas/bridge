import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import { HardhatUserConfig } from "hardhat/config";
import { alchemyApiKey, mnemonic } from "./secrets.json";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 40000,
  },
  networks: {
    hardhat: {},
    sepolia: {
      url: "https://sepolia.infura.io/v3/<key>",
      accounts: { mnemonic: mnemonic },
    },
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${alchemyApiKey}`,
      accounts: { mnemonic: mnemonic },
    },
    sepoliasui: {
      url: `https://eth-rpc.testnet.sui.io:443`,
      accounts: { mnemonic: mnemonic },
    },
  },
};

export default config;
