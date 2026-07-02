require "kemal"

module Harpy
  module Server
    extend self

    @@chain : Chain? = nil
    @@storage_path = Storage::DEFAULT_PATH

    def chain : Chain
      @@chain ||= Storage.load_or_genesis(@@storage_path)
    end

    def reset!(storage_path : String = Storage::DEFAULT_PATH)
      @@chain = nil
      @@storage_path = storage_path
    end

    def configure_kemal!
      Kemal.config do |config|
        config.max_request_body_size = Config.max_request_body_bytes
      end

      Kemal.config.add_error_handler(413) do |env, _ex|
        env.response.content_type = "application/json"
        %({"error":"request body too large"})
      end
    end

    def register_routes!
      get "/" do
        chain.blocks.to_json
      end

      get "/validate" do
        {
          valid:  chain.valid?,
          height: chain.height,
          tip:    chain.empty? ? nil : chain.tip.hash,
        }.to_json
      end

      get "/block/:index" do |env|
        index = env.params.url["index"].to_i
        block = chain.blocks.find { |candidate| candidate.index == index }

        unless block
          halt env, status_code: 404, response: %({"error":"block not found"})
        end

        block.to_json
      end

      post "/new-block" do |env|
        body = env.params.json

        unless data_field = body["data"]?
          halt env, status_code: 400, response: %({"error":"missing data field"})
        end

        unless data_field.is_a?(String)
          halt env, status_code: 400, response: %({"error":"data must be a string"})
        end

        data = data_field

        if data.empty?
          halt env, status_code: 400, response: %({"error":"data cannot be empty"})
        end

        if data.bytesize > Config.max_block_data_bytes
          halt env, status_code: 400, response: %({"error":"block data exceeds maximum size"})
        end

        new_block = Miner.mine_next(chain.tip, data, verbose: true)

        unless chain.append!(new_block)
          halt env, status_code: 422, response: %({"error":"block rejected by chain validation"})
        end

        Storage.save(chain, @@storage_path)
        new_block.to_json
      end
    end

    def start(storage_path : String = Storage::DEFAULT_PATH)
      reset!(storage_path)
      configure_kemal!
      register_routes!
      Kemal.run
    end
  end
end
