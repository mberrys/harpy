module Harpy
  module Config
    extend self

    # Maximum JSON request body for POST /new-block (64 KiB).
    MAX_REQUEST_BODY_BYTES = 64 * 1024

    # Maximum bytes stored in block.data (32 KiB). Must be ≤ MAX_REQUEST_BODY_BYTES.
    MAX_BLOCK_DATA_BYTES = 32 * 1024

    def max_request_body_bytes : Int32
      MAX_REQUEST_BODY_BYTES
    end

    def max_block_data_bytes : Int32
      MAX_BLOCK_DATA_BYTES
    end

    def genesis_difficulty : Int32
      if value = ENV["HARPY_DIFFICULTY"]?
        parsed = value.to_i
        return parsed if parsed >= 0
      end

      Block::DEFAULT_DIFFICULTY
    end
  end
end
