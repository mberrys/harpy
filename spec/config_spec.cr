require "./spec_helper"

describe Harpy::Config do
  it "uses DEFAULT_DIFFICULTY when HARPY_DIFFICULTY is unset" do
    Harpy::SpecHelpers.with_env("HARPY_DIFFICULTY", nil) do
      Harpy::Config.genesis_difficulty.should eq(Harpy::Block::DEFAULT_DIFFICULTY)
    end
  end

  it "reads genesis difficulty from HARPY_DIFFICULTY" do
    Harpy::SpecHelpers.with_env("HARPY_DIFFICULTY", "1") do
      Harpy::Config.genesis_difficulty.should eq(1)
    end
  end

  it "falls back when HARPY_DIFFICULTY is invalid" do
    Harpy::SpecHelpers.with_env("HARPY_DIFFICULTY", "-1") do
      Harpy::Config.genesis_difficulty.should eq(Harpy::Block::DEFAULT_DIFFICULTY)
    end
  end

  it "exposes request and block data size limits" do
    Harpy::Config.max_request_body_bytes.should eq(64 * 1024)
    Harpy::Config.max_block_data_bytes.should eq(32 * 1024)
    Harpy::Config.max_block_data_bytes.should be < Harpy::Config.max_request_body_bytes
  end
end

describe "HARPY_DIFFICULTY genesis bootstrap" do
  it "mines genesis at HARPY_DIFFICULTY when creating a new chain" do
    path = File.tempname

    begin
      Harpy::SpecHelpers.with_env("HARPY_DIFFICULTY", "1") do
        chain = Harpy::Storage.load_or_genesis(path)
        chain.blocks.first.difficulty.should eq(1)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "ignores HARPY_DIFFICULTY when loading an existing chain" do
    path = File.tempname
    original = Harpy::SpecHelpers.build_chain(1, difficulty: 0)

    begin
      Harpy::Storage.save(original, path)

      Harpy::SpecHelpers.with_env("HARPY_DIFFICULTY", "4") do
        loaded = Harpy::Storage.load_or_genesis(path)
        loaded.blocks.first.difficulty.should eq(0)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end
end
