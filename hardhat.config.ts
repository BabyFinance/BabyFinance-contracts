import dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";

dotenv.config();

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {},
    testnet: {
      url: "https://rpc.testnet.fantom.network/",
      accounts: [process.env.PRIVATE_KEY!],
    },
    mainnet: {
      url: "https://rpc.ftm.tools",
      accounts: [process.env.PRIVATE_KEY!],
    },
  },
};

export default config;
