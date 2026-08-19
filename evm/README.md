# QBFT — EVM (Ethereum Sepolia · Base Sepolia)

The ERC-20 implementation of **QBitFlow Test USD (QBFT)** for EVM testnets, plus the deployment script.

> [!WARNING]
> Testnet only. Not audited. Not for mainnet. QBFT has no monetary value.

## Overview

QBFT is a 6-decimal ERC-20 modeled on the **USDC** token contract. Key property: **minting is gated behind a mint authority** held by the QBitFlow app. There is no open/public mint — the faucet is driven by the app so the testnet flow mirrors how tokens move in production.

| Field          | Value                                                                                                          |
| -------------- | ------------------------------------------------------------------------------------------------------------ |
| Name           | QBitFlow Test USD                                                                                             |
| Symbol         | QBFT                                                                                                          |
| Decimals       | 6                                                                                                            |
| Address        | `0xAFC351Dc0bAbb079A45454ACdD1D0dc5801Bab5A` (same on Ethereum Sepolia and Base Sepolia)                     |


Explorers:
- Ethereum Sepolia: https://sepolia.etherscan.io/token/0xAFC351Dc0bAbb079A45454ACdD1D0dc5801Bab5A
- Base Sepolia: https://sepolia.basescan.org/token/0xAFC351Dc0bAbb079A45454ACdD1D0dc5801Bab5A

## Prerequisites

- [Node.js](https://nodejs.org/) and [Hardhat](https://hardhat.org/)
- A funded testnet deployer key (grab test ETH from a Sepolia / Base Sepolia faucet)
- RPC endpoints for the target network(s)

---

## 1. Design summary

| Property | Value |
|---|---|
| Name | QBitFlow Test USD |
| Symbol | QBFT |
| Decimals | **6** (matches USDC/USDT/EURC) |
| Supply | Unlimited (owner-mintable, no cap) |
| Access control | `owner` (mints, admin) + `cosigner` (co-signs governance rotations) |
| Signature scheme | EIP-712, ECDSA, per-signer nonce |
| EVM address | **Same across all chains** via CREATE2 |
| Solana | Standard SPL Token, mint authority = backend keypair |

### Why this design

- **Testnet UX**: backend mints QBFT directly to any user with zero gas required by the user
(backend pays), so onboarding is one API call.
- **No treasury pool**: since minting is free and the token has no cap, `mint(to, amount)` is
the entire faucet primitive. `totalSupply` grows unbounded — irrelevant on testnet.
- **Governance safety**: even though it's a testnet token, `updateOwner` and `updateCosigner`
are cosigner-gated so a leaked deployer key can't silently hijack the token.


---

## 3. EVM: initial deploy (per chain)

### 3.1 Prerequisites

- `hardhat-deploy` installed: `npm i -D hardhat-deploy`
- `.env` populated (see `.env.example`)
- **Deployer EOA funded on the target chain** with a small amount of native gas (~0.02 ETH is
plenty).
- The **CREATE2 factory `0x4e59b44847b379578588920cA78FbF26c0B4956C`** must exist on the
target chain. It exists on virtually all EVM testnets. To verify: `cast code
0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url <RPC>` (or `eth_getCode` via any client)
must return non-empty bytecode. If empty, `hardhat-deploy` will deploy it for you automatically
using the `signedTx` from the config, funded by the deployer.

### 3.2 First-time deploy to Sepolia and Base Sepolia

```bash
npm install
npx hardhat compile

HARDHAT_NETWORK=sepolia npx hardhat run scripts/deploy-qbft.ts --network sepolia
HARDHAT_NETWORK=baseSepolia npx hardhat run scripts/deploy-qbft.ts --network baseSepolia
```

The address logged should be **identical** on both chains. If it's not, something (owner,
cosigner, salt, compiler settings, or bytecode) differs. Do **not** proceed until the addresses
match.

### 3.3 Verify on block explorers

```bash
npx hardhat verify --network sepolia <address> <owner> <cosigner>
npx hardhat verify --network baseSepolia <address> <owner> <cosigner>
```

---

## 4. EVM: adding a new chain later

The whole point of the deterministic setup: **QBFT lives at the same address on every EVM
chain you add**, as long as three things stay constant:
1. The exact same contract bytecode (don't change the Solidity or compiler settings)
2. The same constructor args (`owner`, `cosigner`)
3. The same salt (hardcoded in `scripts/deploy-qbft.ts`)

### Steps

1. Add the new chain to `hardhat.config.ts` under `networks`:
	```typescript
	arbitrumSepolia: {
		url: process.env.ARB_SEPOLIA_RPC_URL!,
		accounts: [DEPLOYER_PK],
		chainId: 421614,
	},
	```
2. Fund the deployer EOA on the new chain (~0.02 native).
3. Confirm the CREATE2 factory exists:
	```bash
	cast code 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url $ARB_SEPOLIA_RPC_URL
	```
	If empty, `hardhat-deploy` will attempt to auto-deploy it — this requires the deployer to
have gas.
4. Deploy:
	```bash
	HARDHAT_NETWORK=arbitrumSepolia npx hardhat deploy --network arbitrumSepolia --tags QBFT
	```
5. Verify:
	```bash
	npx hardhat verify --network arbitrumSepolia <address> <owner> <cosigner>
	```
6. Confirm the resulting address matches Sepolia and Base Sepolia. If not — stop and debug
(see §7).

---

## Minting

Minting is **not** open. Only the mint authority (the QBitFlow app) can mint QBFT; testers receive tokens through the app's faucet. See the [root README](../README.md#how-to-get-qbft-faucet).

## License

MPL-2.0 — see [`../LICENSE`](../LICENSE).