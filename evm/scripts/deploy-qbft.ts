import * as dotenv from "dotenv";
import { network } from "hardhat";
dotenv.config();

const CREATE2_FACTORY = "0x4e59b44847b379578588920cA78FbF26c0B4956C";
const SALT = "0x0000000000000000000000000000000000000000000000000000000051424654";

async function main() {
	const owner = process.env.QBFT_OWNER;
	const cosigner = process.env.QBFT_COSIGNER;
	if (!owner || !cosigner) throw new Error("QBFT_OWNER / QBFT_COSIGNER missing in .env");

	// Pick network via env, e.g. NETWORK=sepolia npx hardhat run scripts/deploy.ts
	const netName = (process.env.HARDHAT_NETWORK ?? "sepolia") as "sepolia" | "baseSepolia";

	console.log(`Deploying QBFT to ${ netName } with owner ${ owner } and cosigner ${ cosigner }`);

	// In HH3, connect() returns an object with `ethers` once hardhat-ethers plugin is loaded.
	const { ethers, networkName } = await network.connect(netName);

	const [deployer] = await ethers.getSigners();
	console.log(`Network:  ${ networkName }`);
	console.log(`Deployer: ${ deployer.address }`);

	const factoryCode = await ethers.provider.getCode(CREATE2_FACTORY);
	if (factoryCode === "0x") {
		throw new Error(`CREATE2 factory not deployed on ${ networkName }.`);
	}

	const QBFT = await ethers.getContractFactory("QBFT");
	const initCode = ethers.concat([
		QBFT.bytecode,
		QBFT.interface.encodeDeploy([owner, cosigner]),
	]);
	const initCodeHash = ethers.keccak256(initCode);
	const predicted = ethers.getCreate2Address(CREATE2_FACTORY, SALT, initCodeHash);
	console.log(`Predicted: ${ predicted }`);

	if ((await ethers.provider.getCode(predicted)) !== "0x") {
		console.log(`✓ Already deployed at ${ predicted }`);
		return;
	}

	const tx = await deployer.sendTransaction({
		to: CREATE2_FACTORY,
		data: ethers.concat([SALT, initCode]),
	});
	console.log(`Deploy tx: ${ tx.hash }`);
	const receipt = await tx.wait(2);
	console.log(`✓ Mined in block ${ receipt!.blockNumber }`);
	console.log(`✓ QBFT at ${ predicted }`);
}

main().catch((e) => { console.error(e); process.exit(1); });