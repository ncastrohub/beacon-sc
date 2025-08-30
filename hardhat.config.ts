import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "dotenv/config";

// ✅ Ensure PRIVATE_KEY is set
const OWNER_PRIVATE_KEY = process.env.OWNER_PRIVATE_KEY;
if (!OWNER_PRIVATE_KEY) {
  throw new Error("Please set your PRIVATE_KEY in a .env file");
}

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    coston2: {
      url: "https://coston2-api.flare.network/ext/C/rpc",
      accounts: [OWNER_PRIVATE_KEY],
      chainId: 114,
    },
  },
};

export default config;