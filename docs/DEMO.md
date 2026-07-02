# Harpy demo walkthrough

This guide walks through running Harpy, exercising the HTTP API, changing proof-of-work difficulty, and running the test suite.

Harpy is an **educational** single-node chain. Its long-term direction is a **verification and anchoring layer** (hash on-chain, payload off-chain) — not a general-purpose data store. See [MIC-81](https://linear.app/mbx2/issue/MIC-81) for the future Merkle anchoring API.

## Prerequisites

```bash
shards install
```

On Windows, see [README.md](../README.md) for Crystal and Developer Mode setup.

## 1. Start with a fresh chain

```bash
rm -f data/chain.json
crystal run src/harpy.cr
```

On first boot the server mines a **genesis block** and saves it to `data/chain.json`. Default difficulty is **3** leading hex zeros (`Harpy::Block::DEFAULT_DIFFICULTY`).

## 2. HTTP demo (curl)

| Step | Command | What to observe |
|------|---------|-----------------|
| View chain | `curl http://localhost:3000/` | JSON array; genesis `hash` starts with `000` |
| Validate | `curl http://localhost:3000/validate` | `{"valid":true,"height":1,"tip":"..."}` |
| Mine a block | `curl -X POST http://localhost:3000/new-block -H "Content-Type: application/json" -d '{"data":"hello harpy"}'` | Mined block JSON; nonce logged in server output |
| Lookup block | `curl http://localhost:3000/block/1` | Block 1 links to genesis via `prev_hash` |
| Persistence | `cat data/chain.json` | Same blocks on disk |

## 3. Change mining difficulty (`HARPY_DIFFICULTY`)

Difficulty applies **only when creating a new chain** (no `data/chain.json` yet). Existing chains keep their stored difficulty.

```bash
rm -f data/chain.json
HARPY_DIFFICULTY=1 crystal run src/harpy.cr   # faster genesis (~1 hex zero)
```

```bash
rm -f data/chain.json
HARPY_DIFFICULTY=4 crystal run src/harpy.cr   # slower genesis (~4 hex zeros)
```

| Difficulty | Leading zeros | Approx. average hashes |
|------------|---------------|-------------------------|
| 1 | `0` | 16 |
| 3 | `000` | 4,096 |
| 4 | `0000` | 65,536 |

New blocks inherit difficulty from the chain tip (`Miner.mine_next` copies the previous block's difficulty).

Invalid values (negative or non-numeric) fall back to `DEFAULT_DIFFICULTY` (3).

## 4. Request size limits

`POST /new-block` enforces two caps (see `Harpy::Config`):

| Limit | Default | HTTP status |
|-------|---------|-------------|
| JSON request body | 64 KiB (`MAX_REQUEST_BODY_BYTES`) | 413 Payload Too Large |
| Block `data` field | 32 KiB (`MAX_BLOCK_DATA_BYTES`) | 400 Bad Request |

Oversized bodies are rejected before JSON parsing/mining. Keep payloads well under 32 KiB for the `data` string itself.

## 5. Automated tests

```bash
crystal spec
crystal tool format --check
shards build
```

Specs use `difficulty: 0` in helpers so mining finishes instantly. Canonical hash vectors live in `spec/fixtures/hash_vectors.json` (see MIC-30).

### Validation rules exercised in tests

- Hash must match `computed_hash` (SHA-256 over index, timestamp, data, prev_hash, nonce — **not** difficulty)
- Proof-of-work: hash prefix matches `difficulty` leading zeros
- Linkage: `index` increments and `prev_hash` matches parent
- Timestamps: child `timestamp` must be **≥ parent** (monotonic)

## 6. Research context

| Layer | What Harpy demonstrates today | Deferred |
|-------|------------------------------|----------|
| **Tutorial** | PoW blocks, HTTP read/write, JSON persistence | P2P, UTXO/accounts |
| **Production readiness** | Deterministic hashing, chain validation, invalid-chain rejection on boot | Rate limits, full threat model |
| **Hardening plan** | `Chain#valid?`, `/validate`, naive longest-chain replacement | Cumulative work fork choice, atomic writes |

Further reading (attached to Linear issues):

- [Production readiness research](https://app.notion.com/p/berrymichael/production-ready-29c4b9c70df84cc8a5a503b845c80541)
- [Security hardening plan](https://app.notion.com/p/3919cb079ddb8132ae08f16afdd9f0a0)

## 7. Anchoring endgame

Harpy's intended integration pattern is **hash on-chain, data off-chain**: applications commit digests (e.g. Merkle roots of audit logs or records) while keeping payloads in IPFS, object storage, or local systems. The chain proves *that* a hash existed at a point in time — it is not a database for arbitrary large blobs.

That path is tracked separately as Merkle anchoring API work (MIC-81); this tutorial branch establishes the block and validation foundation underneath it.
