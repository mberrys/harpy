# Optional PoS long-range checkpointing (decision gate)

**Status:** Decision gate only — **not applicable while Harpy stays PoW.**

Harpy is and remains a **proof-of-work** tutorial chain. This document records long-range / nothing-at-stake risks and external checkpointing patterns **if** the project ever evaluated a move to proof-of-stake.

## Why this matters for PoS (not Harpy today)

In proof-of-stake, validators vote on history. After unbonding, a validator can **rewrite ancient history** at no ongoing slashable cost — the **nothing-at-stake** and **long-range attack** problems. PoW avoids this class via energy expended on the heaviest chain at sync time, at the cost of probabilistic finality.

Without an **external trust anchor**, PoS long-range safety violations are often **non-slashable** after the fact.

## Reference checkpointing designs

| Design | Idea | References |
|--------|------|------------|
| **Babylon** | Bitcoin-anchored timestamps / checkpoints for PoS chains | [arXiv:2207.08392](https://arxiv.org/abs/2207.08392), [arXiv:2201.07946](https://arxiv.org/abs/2201.07946) |
| **Pikachu** | Schnorr + Bitcoin Taproot checkpoints | [arXiv:2208.05408](https://arxiv.org/abs/2208.05408) |

These patterns import **external finality** from a chain with different security assumptions (typically Bitcoin PoW). They are architectural options for **hypothetical** Harpy forks, not current implementation targets.

## Harpy decision record

| Question | Answer |
|----------|--------|
| Is Harpy PoS? | **No** — PoW with cumulative work fork choice |
| Should this doc block Phase 5 P2P? | **No** — informational only |
| If PoS were proposed? | Require new design gate, threat-model update, and explicit rejection of tutorial scope |

## Related documents

- [FINALITY.md](./FINALITY.md) — PoW probabilistic finality (current model)
- [THREAT_MODEL.md](./THREAT_MODEL.md) — consensus layer threats
- [CONFIRMATION_DEPTH.md](./CONFIRMATION_DEPTH.md) — Gervais MDP for PoW depth
