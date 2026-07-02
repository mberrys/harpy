require "./spec_helper"

describe "chain property and fork-choice integration" do
  it "invalidates the chain when any block field is randomly tampered" do
    rng = Random.new(37)

    24.times do
      chain = Harpy::SpecHelpers.build_chain(3 + rng.rand(3))
      block_index = rng.rand(chain.height)
      field = Harpy::SpecHelpers::TAMPER_FIELDS.sample(rng)
      tampered_blocks = chain.blocks.dup
      tampered_blocks[block_index] = Harpy::SpecHelpers.tamper_block(tampered_blocks[block_index], field)

      Harpy::Chain.new(tampered_blocks).valid?.should be_false
    end
  end

  it "rejects forks with equal block count (current block-count fork choice)" do
    main = Harpy::SpecHelpers.build_chain(3)
    genesis = main.blocks.first
    equal_fork = Harpy::SpecHelpers.extend_fork_from(genesis, 3, "equal-length")

    main.replace_if_longer_valid!(equal_fork.blocks).should be_false
    main.height.should eq(3)
  end

  it "rejects forks with fewer blocks" do
    main = Harpy::SpecHelpers.build_chain(4)
    genesis = main.blocks.first
    shorter_fork = Harpy::SpecHelpers.extend_fork_from(genesis, 2, "shorter")

    main.replace_if_longer_valid!(shorter_fork.blocks).should be_false
    main.height.should eq(4)
  end

  it "accepts a longer valid competing chain from the same genesis" do
    main = Harpy::SpecHelpers.build_chain(2)
    genesis = main.blocks.first
    longer_fork = Harpy::SpecHelpers.extend_fork_from(genesis, 4, "longer")

    main.replace_if_longer_valid!(longer_fork.blocks).should be_true
    main.valid?.should be_true
    main.height.should eq(4)
    main.blocks.last.data.should start_with("longer")
  end

  it "rejects an invalid longer candidate even when it has more blocks" do
    main = Harpy::SpecHelpers.build_chain(2)
    genesis = main.blocks.first
    longer_fork = Harpy::SpecHelpers.extend_fork_from(genesis, 4, "longer")
    broken_blocks = longer_fork.blocks.dup
    broken_blocks[2] = Harpy::SpecHelpers.tamper_block(broken_blocks[2], "hash")

    main.replace_if_longer_valid!(broken_blocks).should be_false
    main.height.should eq(2)
  end
end

describe "stored chain boot validation" do
  it "refuses to boot when a mid-chain block hash was tampered on disk" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(3)

    begin
      Harpy::Storage.save(chain, path)
      blocks = Array(Harpy::Block).from_json(File.read(path))
      blocks[1] = Harpy::Block.new(
        blocks[1].index,
        blocks[1].timestamp,
        blocks[1].data,
        blocks[1].prev_hash,
        blocks[1].difficulty,
        blocks[1].nonce,
        "deadbeef",
      )
      File.write(path, blocks.to_json)

      expect_raises Harpy::StorageError do
        Harpy::Storage.load_or_genesis(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end
end
