require "json"
require "log"
require "./config"

module Harpy
  class StorageError < Exception; end

  module Storage
    extend self

    Log = ::Log.for("harpy.storage")

    DEFAULT_PATH = "data/chain.json"

    def load(path : String = DEFAULT_PATH) : Chain?
      return nil unless File.exists?(path)

      blocks = Array(Block).from_json(File.read(path))
      Chain.new(blocks)
    end

    def save(chain : Chain, path : String = DEFAULT_PATH) : Nil
      Dir.mkdir_p(File.dirname(path))
      File.write(path, chain.blocks.to_json)
    end

    def load_or_genesis(path : String = DEFAULT_PATH, verbose : Bool = false) : Chain
      if chain = load(path)
        unless chain.valid?
          Log.error { "chain_load_failed path=#{path} reason=validation_failed" }
          raise StorageError.new("stored chain failed validation")
        end

        chain
      else
        chain = Chain.genesis_chain(difficulty: Config.genesis_difficulty, verbose: verbose)
        save(chain, path)
        chain
      end
    end
  end
end
