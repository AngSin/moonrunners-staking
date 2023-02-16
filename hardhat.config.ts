import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

const privateKey = process.env.PRIVATE_KEY;

if (!privateKey) {
  throw Error('No private Key!');  
}

const apiKey = process.env.API_KEY;

if (!apiKey) {
  throw Error('No api key!');
}

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${apiKey}`,
      accounts: [privateKey]
    },
  },
};

export default config;
