require "./spec_helper"

describe "canonical hash serialization" do
  vectors = JSON.parse(File.read(File.expand_path("fixtures/hash_vectors.json", __DIR__)))

  vectors.as_a.each do |vector|
    description = vector["description"].as_s

    it "matches vector: #{description}" do
      block = Harpy::Block.new(
        vector["index"].as_i,
        vector["timestamp"].as_s,
        vector["data"].as_s,
        vector["prev_hash"].as_s,
        0,
        vector["nonce"].as_s,
      )

      block.computed_hash.should eq(vector["expected_hash"].as_s)
    end
  end

  it "documents that difficulty is excluded from the hash input" do
    base = Harpy::Block.new(0, "2026-01-01", "test", "", 0, "0")
    harder = Harpy::Block.new(0, "2026-01-01", "test", "", 99, "0")

    base.computed_hash.should eq(harder.computed_hash)
  end
end
