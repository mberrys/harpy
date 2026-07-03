# Harpy finality model

Harpy is a **proof-of-work** tutorial chain. It provides **probabilistic finality**, not strong (deterministic) finality. This document explains what that means for operators and how it differs from block production speed.

## Probabilistic vs strong finality

| Model | Definition | Harpy |
|-------|------------|-------|
| **Probabilistic** | Reorg probability drops as confirmations increase, but never reaches zero in theory | **Yes** — PoW + cumulative work |
| **Strong** | Once finalized, a block or transaction cannot be reversed under stated assumptions | **No** — no BFT finality gadget, no checkpoint signatures |

**Block production ≠ finality.** A transaction can appear in the chain tip after one block (~60 s target interval) while still being **reversible** if an attacker publishes a heavier private fork. Operators must wait for sufficient **confirmation depth** before treating a payment as settled.

## How depth reduces risk

1. Each additional block on top of a transaction adds cumulative PoW work an attacker must overcome.
2. Selfish-mining and private-fork attacks remain possible below classical 51% hash power — see [SELFISH_MINING.md](./SELFISH_MINING.md).
3. **Coinbase maturity** ([STATE_MODEL.md](./STATE_MODEL.md) §6) is separate from payment finality: miner rewards require 100 confirmations before spendable, limiting reorg damage to freshly minted coins.

## Harpy-specific confirmation policy

Do not copy Bitcoin's 6 confirmations. Parameterize depth *k* to Harpy's block interval, stale-block rate, and attacker model using the [Gervais MDP framework](./CONFIRMATION_DEPTH.md) ([MIC-71](https://linear.app/mbx2/issue/MIC-71)).

| Risk tolerance | Suggested *k* (Δ = 60 s) | Wall-clock |
|----------------|--------------------------|------------|
| Classroom demo | 1–3 | 1–3 min |
| Staging / untrusted writers | 6 | ~6 min |
| High-value (still educational only) | 8+ | ~8 min |

Single-node local dev: the chain tip is authoritative — depth 1 is fine because there is no competing network view.

## What Harpy does not guarantee

- **Instant irreversibility** after inclusion in a block
- **Cross-chain portability** of confirmation counts (Ethereum ≠ Bitcoin ≠ Harpy)
- **Strong finality** under network partition or eclipse — deferred to P2P hardening ([MIC-68](https://linear.app/mbx2/issue/MIC-68))
- **Production settlement** — Harpy is educational; remeasure *k* on any deployment fork

## Decoupling production from settlement

Tutorial APIs (`POST /tx`, `POST /mine`) make blocks appear quickly. Application logic should:

1. Accept a tx into the mempool → **unconfirmed**
2. Include in a mined block → **visible at depth 1**
3. Wait until `confirmations >= k` → **operationally final** for the chosen risk level
4. Wait until `confirmations >= COINBASE_MATURITY` before spending miner rewards

A future API may expose per-tx confirmation counts on `GET /validate` or a dedicated endpoint.

## Related documents

- [CONFIRMATION_DEPTH.md](./CONFIRMATION_DEPTH.md) — Gervais MDP parameterization and *k* tables
- [SELFISH_MINING.md](./SELFISH_MINING.md) — attacker hash thresholds
- [STATE_MODEL.md](./STATE_MODEL.md) — UTXO, coinbase maturity, fees
- [THREAT_MODEL.md](./THREAT_MODEL.md) — consensus and network threats
