require "./merkle"

module Harpy
  # Merkle anchoring (MIC-81): applications submit record hashes; Harpy batches the
  # pending set into a Merkle root, commits that root on-chain in the next mined
  # block's `anchor_root` (part of the block's PoW hash), and can then return an
  # inclusion proof for any anchored record. Core pattern: hash-on-chain, data
  # off-chain — the chain proves a record hash existed at a point in time.
  #
  # State is in-memory: the durable commitment is the on-chain `anchor_root`; the
  # record→proof index here is a convenience that does not survive a restart or a
  # reorg that drops a sealing block (documented limitation for the tutorial).
  module Anchor
    extend self

    @@mutex = Mutex.new
    @@pending = [] of String
    @@sealed = Hash(String, Array(String)).new # sealing block hash → anchored leaves
    @@record_block = Hash(String, String).new  # record hash → sealing block hash

    record PendingBatch, root : String, leaves : Array(String)

    # Queue a record hash for the next block. Returns false for a malformed hash.
    def submit(record_hash : String) : Bool
      return false unless valid_hash?(record_hash)

      @@mutex.synchronize do
        @@pending << record_hash unless @@pending.includes?(record_hash)
      end
      true
    end

    def pending : Array(String)
      @@mutex.synchronize { @@pending.dup }
    end

    # Merkle root of the current pending batch, or "" when nothing is pending
    # (empty root means the mined block omits `anchor_root` entirely).
    def pending_root : String
      @@mutex.synchronize do
        return "" if @@pending.empty?

        Merkle.root(@@pending)
      end
    end

    # Atomically snapshot pending leaves for mining. Clears them so submissions
    # during PoW queue for the following block instead of the in-flight batch.
    def take_pending_batch! : PendingBatch?
      @@mutex.synchronize do
        return nil if @@pending.empty?

        leaves = @@pending.dup
        root = Merkle.root(leaves)
        @@pending.clear
        PendingBatch.new(root, leaves)
      end
    end

    # Record that `block_hash` sealed exactly `leaves` (must match the mined anchor_root).
    def seal!(block_hash : String, leaves : Array(String)) : Nil
      return if leaves.empty?

      @@mutex.synchronize do
        @@sealed[block_hash] = leaves
        leaves.each { |h| @@record_block[h] = block_hash }
      end
    end

    record Proof, block_hash : String, proof : Array(Merkle::ProofStep)

    # Inclusion proof for a previously anchored record, or nil if unknown.
    def proof_for(record_hash : String) : Proof?
      @@mutex.synchronize do
        block_hash = @@record_block[record_hash]?
        return nil unless block_hash

        leaves = @@sealed[block_hash]?
        return nil unless leaves

        position = leaves.index(record_hash)
        return nil unless position

        Proof.new(block_hash, Merkle.proof(leaves, position))
      end
    end

    # Drop index entries for blocks no longer on the canonical chain (after reorg).
    def prune_orphaned!(canonical_hashes : Set(String)) : Nil
      @@mutex.synchronize do
        @@sealed.select! { |hash, _| canonical_hashes.includes?(hash) }
        @@record_block.select! { |_, hash| canonical_hashes.includes?(hash) }
      end
    end

    def reset! : Nil
      @@mutex.synchronize do
        @@pending.clear
        @@sealed.clear
        @@record_block.clear
      end
    end

    private def valid_hash?(hash : String) : Bool
      hash.size == 64 && hash.each_char.all? { |c| c.ascii_number? || ('a'..'f').includes?(c) }
    end
  end
end
