# Sybil resistance assumptions (Harpy PoW)

Harpy is a **permissionless proof-of-work** tutorial chain. This document records Sybil-resistance assumptions for the threat model ([MIC-33](https://linear.app/mbx2/issue/MIC-33), [THREAT_MODEL.md](./THREAT_MODEL.md)).

## Core assumption

Permissionless participation requires a **scarce resource** to bound identity creation. Harpy uses **proof-of-work**: extending the chain costs CPU cycles proportional to `16^difficulty` per block.

Without such a cost, an attacker could create unlimited identities (fake nodes, sock-puppet miners) at negligible expense.

## Formal trilemma (Platt & McBurney)

No protocol can simultaneously achieve all three:

1. **Strong permissionlessness** — anyone can join without gatekeepers
2. **Sybil resistance** — adversary cannot cheaply multiply influence
3. **Zero cost of participation** — no resource burn to participate

Harpy chooses **(1) + (2)** via PoW and accepts **CPU cost** for miners. HTTP API rate limits ([MIC-41](https://linear.app/mbx2/issue/MIC-41)) add a separate **operational** bound on write abuse but are not a Sybil-resistance mechanism for consensus.

## Harpy today vs with P2P

| Phase | Sybil surface | Mitigation |
|-------|---------------|------------|
| **Single-node (now)** | No P2P peer identities | PoW on block extension; optional `HARPY_API_KEY` on writes |
| **P2P (Phase 5)** | Fake peers, eclipse, partition | Peer limits, handshake, ban list ([MIC-68](https://linear.app/mbx2/issue/MIC-68)); diverse peer selection ([MIC-87](https://linear.app/mbx2/issue/MIC-87)) |

Until P2P ships, threat §7 in [THREAT_MODEL.md](./THREAT_MODEL.md) is **not yet applicable** at the network layer. PoW still bounds **chain extension** cost on the single node.

## Shard-based designs (out of scope)

Shard-based systems split validator sets per shard, which can **lower per-shard security** if stake or hash power is spread thin ([arXiv:2002.06531](https://arxiv.org/abs/2002.06531)). Harpy is **not sharded** — one linear chain, one cumulative-work tip.

## Bandwidth-based alternatives

Research explores bandwidth quotas as an anti-Sybil signal (e.g. "Selfied" and related work). Harpy does **not** implement bandwidth proofs; PoW remains the sole consensus Sybil bound.

## Operator guidance

| Deployment | Recommendation |
|------------|----------------|
| Local tutorial | Sybil risk minimal (no peers) |
| Exposed HTTP node | `HARPY_API_KEY`, rate limits, firewall — limits **API** abuse, not consensus Sybil at P2P layer |
| Future multi-node | Enforce peer diversity; never rely on a single bootstrap; implement [MIC-68](https://linear.app/mbx2/issue/MIC-68) before production-like tests |

## Related documents

- [THREAT_MODEL.md](./THREAT_MODEL.md) — threat catalog §7
- [SELFISH_MINING.md](./SELFISH_MINING.md) — hash-power games (distinct from identity flood)
- [FINALITY.md](./FINALITY.md) — confirmation depth under PoW
