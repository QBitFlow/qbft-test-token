# QBitFlow Test USD (QBFT)

Testnet-only token implementations used to make **testing [QBitFlow](https://qbitflow.app) integrations painless** — spin up a merchant flow, grab faucet tokens, and exercise real stablecoin payment paths without touching mainnet or spending a cent.

> [!WARNING]
> **This is a testnet asset. It has no monetary value.**
> QBFT exists only on public test networks (Ethereum Sepolia, Base Sepolia, Solana devnet). The contracts here are **not audited** and are **not intended for mainnet deployment**. Do not treat QBFT as a real stablecoin.

---

## Why this exists

Integrating a payment stack is the kind of thing you want to get wrong *cheaply*. Real USDC/USDT on mainnet means real money, gas, and off-ramp friction just to confirm your checkout wiring works.

QBFT removes that. It's a faucet-mintable stand-in for a real dollar stablecoin that behaves like the assets QBitFlow settles in, so you can build and validate an integration end-to-end on testnets first.

QBFT is modeled on the **USDC** token implementation (USDT behaves near-identically for integration purposes), so what you test against QBFT maps cleanly to production behavior.

> **QBitFlow does not, and will not, deploy its own mainnet token.** QBFT is a testing utility — nothing more. In production, QBitFlow settles in established stablecoins.

---

## Token details

| Field            | Value                                                              |
| ---------------- | ----------------------------------------------------------------- |
| Name             | QBitFlow Test USD                                                  |
| Symbol           | QBFT                                                               |
| Decimals         | 6                                                                  |
| Networks         | Ethereum Sepolia · Base Sepolia · Solana devnet                   |
| Mint authority   | Held by the QBitFlow app (see below)                               |
| License          | MPL-2.0                                                            |

### Deployed addresses

| Network            | Address                                                                                                                                          |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum Sepolia   | [`0xAFC351Dc0bAbb079A45454ACdD1D0dc5801Bab5A`](https://sepolia.etherscan.io/token/0xAFC351Dc0bAbb079A45454ACdD1D0dc5801Bab5A)                  |
| Base Sepolia       | [`0xAFC351Dc0bAbb079A45454ACdD1D0dc5801Bab5A`](https://sepolia.basescan.org/token/0xAFC351Dc0bAbb079A45454ACdD1D0dc5801Bab5A)                  |
| Solana devnet      | [`B3JpxdErAnh3cEWggiqmvNHUVBT6E19Ac945EX3kuUUU`](https://explorer.solana.com/address/B3JpxdErAnh3cEWggiqmvNHUVBT6E19Ac945EX3kuUUU?cluster=devnet) |

> The EVM address is identical on Ethereum Sepolia and Base Sepolia.

---

## How to get QBFT (faucet)

QBFT is **not** openly mintable. The mint authority is held by the QBitFlow app, and tokens are dispensed through the app's testnet faucet — the same way a tester would receive them in a real onboarding flow.

To get test tokens, use the faucet in the QBitFlow app *(link: https://qbitflow.app/tools/faucets)*. Direct calls to the mint function will revert for anyone other than the mint authority.

---

## Repository layout

```
qbft-test-token/
├── evm 			# ERC-20 contract + deploy script (Ethereum Sepolia, Base Sepolia)
│   ├── contracts
│   │   └── QBFT.sol
│   ├── hardhat.config.ts
│   ├── package-lock.json
│   ├── package.json
│   ├── README.md
│   └── scripts
│       └── deploy-qbft.ts
├── sol				# How the SPL token was deployed via the Solana CLI
│   ├── qbft.json
│   └── README.md
├── LICENSE       # MPL-2.0
└── README.md
```

- **[`evm/`](./evm)** — the QBFT ERC-20 implementation (USDC-model, with a restricted mint authority) and its deployment script.
- **[`sol/`](./sol)** — a walkthrough of how the QBFT SPL token mint was created and configured with the Solana CLI. No on-chain program source lives here; QBFT uses the standard SPL Token program.

---

## License

Licensed under the **Mozilla Public License 2.0** — see [`LICENSE`](./LICENSE), consistent with the rest of the QBitFlow codebase.