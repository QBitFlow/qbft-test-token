# QBFT — Solana (devnet)

How **QBitFlow Test USD (QBFT)** was deployed on Solana devnet.

> [!WARNING]
> Testnet only. QBFT has no monetary value and exists solely to test QBitFlow integrations.

## Overview

On Solana, QBFT is a standard **SPL Token** mint — no custom on-chain program. It was created and configured with the Solana / SPL Token CLI, with the **mint authority retained by the QBitFlow app** so the faucet is app-driven (mirroring the EVM setup and production behavior).

| Field            | Value                                          |
| ---------------- | ---------------------------------------------- |
| Name             | QBitFlow Test USD                              |
| Symbol           | QBFT                                           |
| Decimals         | 6                                              |
| Cluster          | devnet                                         |
| Mint address     | `B3JpxdErAnh3cEWggiqmvNHUVBT6E19Ac945EX3kuUUU` |

Explorer: https://explorer.solana.com/address/B3JpxdErAnh3cEWggiqmvNHUVBT6E19Ac945EX3kuUUU?cluster=devnet

## Concept mapping

| EVM (contract) | Solana equivalent |
|---|---|
| `ERC20` contract | An **SPL Mint account** |
| `decimals = 6` | `--decimals 6` on `spl-token create-token` |
| `owner` (can mint) | **Mint Authority** on the mint account |
| `mint(to, amount)` | `spl-token mint <MINT> <AMOUNT> <RECIPIENT>` |
| `updateOwner(newOwner, ...)` | `spl-token authorize <MINT> mint <NEW_AUTHORITY>` |
| Freezing/blacklisting (not in contract) | Freeze Authority (you can disable it) |
| Token balance per user | Associated Token Account (ATA) per wallet |
| Cosigner + EIP-712 rotation | Use a **multisig mint authority** (native SPL feature) |

The `cosigner` pattern is where Solana diverges — instead of signature verification inside a program, you set the mint authority to an **SPL Token multisig** (M-of-N), which is a first-class primitive. I'll show that as an optional step.

---

## Prerequisites

- [Solana CLI](https://docs.solanalabs.com/cli/install) (`solana`, `solana-keygen`)
- [SPL Token CLI](https://spl.solana.com/token) (`spl-token`)

--- 

## Step 1 — Install tooling

```bash
sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
cargo install spl-token-cli
# verify
solana --version
spl-token --version
```

## Step 2 — Configure devnet and a keypair

```bash
solana config set --url https://api.devnet.solana.com
solana-keygen new --outfile ~/.config/solana/qbft-owner.json
solana config set --keypair ~/.config/solana/qbft-owner.json
solana address
solana airdrop 2
solana balance
```

If the airdrop rate-limits you, use https://faucet.solana.com.

## Step 3 — Create the mint (the "token contract")

```bash
spl-token create-token \
  --decimals 6 \
  --mint-authority $(solana address) 



# Token program 2022 metadata extension (optional, but recommended for name/symbol):
spl-token create-token \
	--program-2022 \
	--decimals 6 \
	--mint-authority $(solana address) \
	--enable-metadata
```

Output includes a mint address, e.g. `MintXyz...`. **Save it** — this is your token's canonical identifier (equivalent to the ERC20 contract address).

By default:
- **Mint authority** = your keypair (only you can mint ✅)
- **Freeze authority** = your keypair

Since your EVM version has no freeze/blacklist, disable it permanently:

```bash
spl-token authorize <MINT> freeze --disable
```

### (Optional) Attach metadata (name/symbol)

Using the Token-2022 metadata extension (`--enable-metadata` above uses Token-2022):

```bash
spl-token initialize-metadata <MINT> "QBitFlow Test USD" "QBFT" <URI_TO_JSON>
```

`<URI_TO_JSON>` should point to a JSON file (e.g. on Arweave/IPFS/GitHub raw) like:

```json
{
  "name": "QBitFlow Test USD",
  "symbol": "QBFT",
  "description": "QBitFlow devnet faucet token",
  "image": "https://.../qbft.png"
}
```

> If you prefer the classic Token program + Metaplex Token Metadata instead of Token-2022, omit `--enable-metadata` and use `sugar` or `mpl-token-metadata` — but Token-2022 is simpler here.

## Step 4 — Mint to yourself (sanity check)

```bash
# Creates your ATA and mints 1,000,000 QBFT (6 decimals) to you
spl-token create-account <MINT>
spl-token mint <MINT> 1000000
spl-token balance <MINT>
```

## Step 5 — Faucet: mint to a user

This is the direct equivalent of your `mint(to, amount)` function:

```bash
# amount is in UI units (6 decimals handled automatically)
spl-token mint <MINT> 100 --recipient-owner <USER_WALLET_PUBKEY>
```

`--recipient-owner` auto-derives and creates the user's ATA if missing. You pay the ~0.002 SOL rent for the ATA the first time.

### Programmatic faucet (Node.js/TS backend)

For a real faucet endpoint, use `@solana/web3.js` + `@solana/spl-token`:

```ts
import { Connection, Keypair, PublicKey } from "@solana/web3.js";
import {
  getOrCreateAssociatedTokenAccount,
  mintTo,
  TOKEN_2022_PROGRAM_ID,
} from "@solana/spl-token";

const connection = new Connection("https://api.devnet.solana.com", "confirmed");
const authority = Keypair.fromSecretKey(/* load from KMS/secret manager */);
const mint = new PublicKey("<MINT>");

export async function faucet(userPubkey: string, uiAmount: number) {
  const user = new PublicKey(userPubkey);
  const ata = await getOrCreateAssociatedTokenAccount(
    connection, authority, mint, user, false, "confirmed", undefined,
    TOKEN_2022_PROGRAM_ID,
  );
  const amount = BigInt(Math.floor(uiAmount * 1e6)); // 6 decimals
  return mintTo(
    connection, authority, mint, ata.address, authority, amount,
    [], undefined, TOKEN_2022_PROGRAM_ID,
  );
}
```

Add your own rate limiting, captcha, per-wallet caps, etc. at the HTTP layer.

## Step 6 — Rotating the mint authority (your `updateOwner`)

```bash
# Transfer mint authority to a new keypair
spl-token authorize <MINT> mint <NEW_AUTHORITY_PUBKEY>

# Or renounce forever (irreversible — like setting owner to address(0))
spl-token authorize <MINT> mint --disable
```

The signer of this tx must be the **current** mint authority. That's the native equivalent of your `onlyOwner` check.

---

## Step 7 (Optional but recommended) — Cosigner via SPL multisig

To replicate your `owner + cosigner` pattern properly, make the mint authority a **2-of-2 (or 1-of-2, 2-of-3, etc.) SPL multisig**:

```bash
# Create a 2-of-2 multisig with owner + cosigner as signers
spl-token create-multisig 2 <OWNER_PUBKEY> <COSIGNER_PUBKEY>
# → outputs <MULTISIG_ADDRESS>

# Set it as the mint authority
spl-token authorize <MINT> mint <MULTISIG_ADDRESS>
```

Now every `mint` call requires both signatures:

```bash
spl-token mint <MINT> 100 --recipient-owner <USER> \
  --owner <MULTISIG_ADDRESS> \
  --multisig-signer <OWNER_KEYPAIR>.json \
  --multisig-signer <COSIGNER_KEYPAIR>.json
```

For a **faucet** you probably want 1-of-2 (either key can mint) so your backend isn't blocked. For **governance rotation** (changing the authority itself), a 2-of-2 is safer — but note that with a plain multisig, you'd need a separate multisig for the "governance" role vs. the "operational mint" role, which the SPL model doesn't compose. If you need the full EIP-712 nonce-based rotation semantics, that would require a small custom Anchor program — but honestly, on devnet it's overkill.

## Why no EIP-712 / signature-gated rotation on Solana?

- Solana txs are already signed by the required authority accounts; there's no "msg.sender" spoofing to defend against.
- Replay protection is built into the runtime (recent blockhash + tx dedup).
- Multi-party approval is the native `Multisig` account.

So the idiomatic translation of your EVM contract is: **plain SPL mint + multisig authority**. No program deployment needed.

---

## TL;DR command sequence

```bash
solana config set --url devnet
solana-keygen new -o ~/.config/solana/qbft-owner.json
solana config set --keypair ~/.config/solana/qbft-owner.json
solana airdrop 2

spl-token create-token --decimals 6 --enable-metadata
# → save MINT address
spl-token authorize <MINT> freeze --disable
spl-token initialize-metadata <MINT> "QBitFlow Test USD" "QBFT" <URI>

spl-token create-account <MINT>
spl-token mint <MINT> 100 --recipient-owner <USER_PUBKEY>   # faucet call
```

## Getting QBFT

Minting is restricted to the app's mint authority. Testers receive QBFT through the QBitFlow app's faucet — see the [root README](../README.md#how-to-get-qbft-faucet).

## License

MPL-2.0 — see [`../LICENSE`](../LICENSE).
