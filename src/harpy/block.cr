require "digest/sha256"
require "json"

module Harpy
  struct Block
    include JSON::Serializable

    DEFAULT_DIFFICULTY = 3

    getter index : Int32
    getter timestamp : String
    getter data : String
    getter hash : String
    getter prev_hash : String
    getter difficulty : Int32
    getter nonce : String

    def initialize(
      @index : Int32,
      @timestamp : String,
      @data : String,
      @prev_hash : String,
      @difficulty : Int32 = DEFAULT_DIFFICULTY,
      @nonce : String = "",
      @hash : String = "",
    )
    end

    def computed_hash : String
      plain_text = "
      #{@index}
      #{@timestamp}
      #{@data}
      #{@prev_hash}
      #{@nonce}
    "

      Digest::SHA256.hexdigest(plain_text)
    end

    def pow_valid? : Bool
      @hash.starts_with?("0" * @difficulty)
    end

    # Expected hash trials for `difficulty` leading hex zeroes (16^difficulty).
    def work : UInt64
      1_u64 << (4 * @difficulty)
    end

    def hash_matches? : Bool
      @hash == computed_hash
    end

    def valid_against?(previous : Block) : Bool
      return false unless @index == previous.index + 1
      return false unless @prev_hash == previous.hash
      return false unless timestamp_not_before?(previous)
      return false unless hash_matches?
      return false unless pow_valid?

      true
    end

    private def timestamp_not_before?(previous : Block) : Bool
      self_time = parse_timestamp(@timestamp)
      prev_time = parse_timestamp(previous.timestamp)
      self_time >= prev_time
    rescue Time::Format::Error
      false
    end

    private def parse_timestamp(value : String) : Time
      Time.parse(value, "%Y-%m-%d %H:%M:%S UTC", Time::Location::UTC)
    end

    def self.genesis(
      data : String = "Genesis block's data!",
      timestamp : String = Time.utc.to_s,
      difficulty : Int32 = DEFAULT_DIFFICULTY,
    ) : Block
      new(0, timestamp, data, "", difficulty)
    end
  end
end
