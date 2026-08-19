import hardhatEthers from "@nomicfoundation/hardhat-ethers";
import hardhatVerify from "@nomicfoundation/hardhat-verify";
import * as dotenv from "dotenv";
import type { HardhatUserConfig } from "hardhat/config";
dotenv.config();

const config: HardhatUserConfig = {
	plugins: [hardhatEthers, hardhatVerify],           // ← this is what attaches `.ethers` to connections
	solidity: {
		version: "0.8.35",
		settings: { optimizer: { enabled: true, runs: 200 } },
	},
	networks: {
		sepolia: {
			type: "http",
			chainType: "l1",
			url: process.env.SEPOLIA_RPC_URL!,
			accounts: [process.env.DEPLOYER_PK!],
			chainId: 11155111,
		},
		baseSepolia: {
			type: "http",
			chainType: "l1",                // keep uniform; plain ERC20 doesn't need OP tooling
			url: process.env.BASE_SEPOLIA_RPC_URL!,
			accounts: [process.env.DEPLOYER_PK!],
			chainId: 84532,
		},
	},
	verify: {
		etherscan: {
			apiKey: process.env.ETHERSCAN_API_KEY!,
			// Etherscan V2 uses a single key for all chains now
		},
		// Optional: Blockscout
		blockscout: {
			enabled: false,
		},
	},
};

export default config;