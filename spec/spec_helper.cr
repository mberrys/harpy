require "spec"
require "../src/harpy/*"

module Harpy::SpecHelpers
  def self.mined_genesis(difficulty : Int32 = 0) : Harpy::Block
    Harpy::Miner.mine(Harpy::Block.genesis(difficulty: difficulty))
  end

  def self.build_chain(block_count : Int32, difficulty : Int32 = 0) : Harpy::Chain
    chain = Harpy::Chain.new([mined_genesis(difficulty)])

    (1...block_count).each do |index|
      chain.append!(Harpy::Miner.mine_next(chain.tip, "block #{index}", verbose: false)).should be_true
    end

    chain
  end

  def self.with_env(key : String, value : String?, &)
    previous = ENV[key]?
    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end

    begin
      yield
    ensure
      if previous.nil?
        ENV.delete(key)
      else
        ENV[key] = previous
      end
    end
  end

  TAMPER_FIELDS = %w(index timestamp data prev_hash difficulty nonce hash)

  def self.tamper_block(block : Harpy::Block, field : String) : Harpy::Block
    case field
    when "index"      then Harpy::Block.new(block.index + 1, block.timestamp, block.data, block.prev_hash, block.difficulty, block.nonce, block.hash)
    when "timestamp"  then Harpy::Block.new(block.index, "1970-01-01 00:00:00 UTC", block.data, block.prev_hash, block.difficulty, block.nonce, block.hash)
    when "data"       then Harpy::Block.new(block.index, block.timestamp, "#{block.data}-tampered", block.prev_hash, block.difficulty, block.nonce, block.hash)
    when "prev_hash"  then Harpy::Block.new(block.index, block.timestamp, block.data, "deadbeef", block.difficulty, block.nonce, block.hash)
    when "difficulty" then Harpy::Block.new(block.index, block.timestamp, block.data, block.prev_hash, block.difficulty + 1, block.nonce, "deadbeef")
    when "nonce"      then Harpy::Block.new(block.index, block.timestamp, block.data, block.prev_hash, block.difficulty, "ffff", block.hash)
    when "hash"       then Harpy::Block.new(block.index, block.timestamp, block.data, block.prev_hash, block.difficulty, block.nonce, "deadbeef")
    else                   raise "unknown field: #{field}"
    end
  end

  def self.extend_fork_from(
    genesis : Harpy::Block,
    block_count : Int32,
    label : String = "fork",
    difficulty : Int32? = nil,
  ) : Harpy::Chain
    fork = Harpy::Chain.new([genesis])
    (1...block_count).each do |index|
      block_difficulty = difficulty || fork.tip.difficulty
      candidate = Harpy::Block.new(
        fork.tip.index + 1,
        Time.utc.to_s,
        "#{label} #{index}",
        fork.tip.hash,
        block_difficulty,
      )
      fork.append!(Harpy::Miner.mine(candidate)).should be_true
    end
    fork
  end
end
