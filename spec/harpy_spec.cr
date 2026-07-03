require "./spec_helper"

describe Harpy::Block do
  it "has a version" do
    Harpy::VERSION.should eq("0.1.0")
  end

  it "computes a deterministic hash" do
    block = Harpy::Block.new(0, "2026-01-01", "test", "", 0, "0")
    hash = block.computed_hash

    hash.size.should eq(64)
    Harpy::Block.new(0, "2026-01-01", "test", "", 0, "0").computed_hash.should eq(hash)
  end

  it "validates proof-of-work difficulty" do
    Harpy::Block.new(0, "2026-01-01", "test", "", 3, "0", "000abc").pow_valid?.should be_true
    Harpy::Block.new(0, "2026-01-01", "test", "", 3, "0", "00abc").pow_valid?.should be_false
  end

  it "validates linkage and hash integrity against the previous block" do
    genesis = Harpy::SpecHelpers.mined_genesis
    next_block = Harpy::Miner.mine_next(genesis, "block two")

    next_block.valid_against?(genesis).should be_true
  end

  it "rejects blocks with a tampered hash" do
    genesis = Harpy::SpecHelpers.mined_genesis
    next_block = Harpy::Miner.mine_next(genesis, "block two")
    tampered = Harpy::Block.new(
      next_block.index,
      next_block.timestamp,
      next_block.data,
      next_block.prev_hash,
      next_block.difficulty,
      next_block.nonce,
      "deadbeef",
    )

    tampered.valid_against?(genesis).should be_false
  end

  it "accepts a child block with the same timestamp as its parent" do
    genesis = Harpy::SpecHelpers.mined_genesis
    same_time = Harpy::Miner.mine(
      Harpy::Block.new(1, genesis.timestamp, "same time", genesis.hash, genesis.difficulty),
    )

    same_time.valid_against?(genesis).should be_true
  end

  it "rejects a child block with a timestamp before its parent" do
    genesis = Harpy::SpecHelpers.mined_genesis
    backdated = Harpy::Miner.mine(
      Harpy::Block.new(1, "2020-01-01 00:00:00 UTC", "backdated", genesis.hash, genesis.difficulty),
    )

    backdated.valid_against?(genesis).should be_false
  end

  it "accepts a block with data at the configured size cap" do
    genesis = Harpy::SpecHelpers.mined_genesis
    next_block = Harpy::Miner.mine_next(genesis, "y" * Harpy::Config.max_block_data_bytes)

    next_block.data_within_limit?.should be_true
    next_block.valid_against?(genesis).should be_true
  end

  it "rejects a block with data exceeding the configured size cap, even if mined and hash-valid" do
    genesis = Harpy::SpecHelpers.mined_genesis
    oversized = Harpy::Miner.mine_next(genesis, "y" * (Harpy::Config.max_block_data_bytes + 1))

    oversized.data_within_limit?.should be_false
    oversized.valid_against?(genesis).should be_false
  end
end

describe Harpy::Chain do
  it "validates a mined chain end to end" do
    chain = Harpy::SpecHelpers.build_chain(3)

    chain.valid?.should be_true
    chain.height.should eq(3)
  end

  it "rejects blocks that do not link to the tip" do
    chain = Harpy::SpecHelpers.build_chain(2)
    orphan = Harpy::Miner.mine(Harpy::Block.new(99, Time.utc.to_s, "orphan", "missing", 0))

    chain.append!(orphan).should be_false
    chain.height.should eq(2)
  end

  it "rejects appending a block with a regressive timestamp" do
    chain = Harpy::SpecHelpers.build_chain(2)
    tip = chain.tip
    backdated = Harpy::Miner.mine(
      Harpy::Block.new(tip.index + 1, "2020-01-01 00:00:00 UTC", "backdated", tip.hash, tip.difficulty),
    )

    chain.append!(backdated).should be_false
    chain.height.should eq(2)
  end

  it "replaces the chain only with a valid candidate that has more cumulative work" do
    chain = Harpy::SpecHelpers.build_chain(2)
    longer = Harpy::SpecHelpers.build_chain(3)

    chain.replace_if_more_work_valid!(longer.blocks).should be_true
    chain.height.should eq(3)

    shorter = Harpy::SpecHelpers.build_chain(2)
    chain.replace_if_more_work_valid!(shorter.blocks).should be_false
    chain.height.should eq(3)
  end

  it "sums cumulative work as 16^difficulty per block" do
    chain = Harpy::SpecHelpers.build_chain(3, difficulty: 2)

    chain.cumulative_work.should eq(3_u64 * (1_u64 << 8))
  end
end

describe Harpy::Storage do
  it "round-trips a valid chain to disk" do
    path = File.tempname
    original = Harpy::SpecHelpers.build_chain(2)

    begin
      Harpy::Storage.save(original, path)
      loaded = Harpy::Storage.load(path)

      loaded.should_not be_nil
      loaded.not_nil!.valid?.should be_true
      loaded.not_nil!.blocks.to_json.should eq(original.blocks.to_json)
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "refuses to boot from an invalid stored chain" do
    path = File.tempname
    invalid = Harpy::Chain.new([Harpy::Block.new(0, "2026-01-01", "bad", "", 0, "0", "invalid")])

    begin
      Harpy::Storage.save(invalid, path)
      expect_raises Harpy::StorageError do
        Harpy::Storage.load_or_genesis(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "refuses to boot from a stored chain with an oversize genesis payload" do
    path = File.tempname
    oversized_genesis = Harpy::Miner.mine(
      Harpy::Block.genesis("y" * (Harpy::Config.max_block_data_bytes + 1), difficulty: 0),
    )
    invalid = Harpy::Chain.new([oversized_genesis])

    begin
      Harpy::Storage.save(invalid, path)
      expect_raises Harpy::StorageError do
        Harpy::Storage.load_or_genesis(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end
end
