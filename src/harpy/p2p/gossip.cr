require "log"
require "socket"
require "./protocol"
require "./orphan_pool"
require "./peer_manager"
require "./reputation"
require "./eclipse"
require "../chain"
require "../storage"

module Harpy
  module P2p
    class Network
      Log = ::Log.for("harpy.p2p")

      getter orphan_pool : OrphanPool
      getter peer_manager : PeerManager
      getter chain : Chain
      getter port : Int32
      getter running : Bool

      def initialize(
        @chain : Chain,
        @storage_path : String,
        @port : Int32 = Config.p2p_port,
        @mutex : Mutex = Mutex.new,
      )
        @orphan_pool = OrphanPool.new
        @peer_manager = PeerManager.new
        @server = nil
        @running = false
      end

      def start : Nil
        return if @running

        @running = true
        spawn { accept_loop }
        Config.p2p_peers.each { |address| spawn { connect_outbound(address) } }
      end

      def stop : Nil
        @running = false
        @server.try &.close
        @peer_manager.peers.each { |peer| peer.socket.try &.close }
      end

      def broadcast_block(block : Block) : Nil
        message = Message.inv([block.hash])
        @peer_manager.peers.each do |peer|
          next if @peer_manager.reputation.deprioritized?(peer.address)

          peer.send_message(message)
        end
      end

      def handle_incoming_block(block : Block, peer_address : String) : Chain::BlockAcceptResult
        result = @mutex.synchronize do
          accept = @chain.accept_block!(block, @orphan_pool)
          case accept
          when Chain::BlockAcceptResult::Connected, Chain::BlockAcceptResult::Reorganized
            Storage.save(@chain, @storage_path)
            @peer_manager.reputation.reward(peer_address)
          when Chain::BlockAcceptResult::Rejected
            @peer_manager.record_misbehavior(peer_address, 2)
          end
          accept
        end

        if result.in?({Chain::BlockAcceptResult::Connected, Chain::BlockAcceptResult::Reorganized, Chain::BlockAcceptResult::Orphaned})
          broadcast_block(block)
        end

        result
      end

      private def accept_loop : Nil
        @server = TCPServer.new("0.0.0.0", @port)
        Log.info { "p2p_listening port=#{@port}" }

        while @running
          begin
            socket = @server.not_nil!.accept
            address = socket.remote_address.try(&.to_s) || "unknown"
            spawn { handle_connection(socket, address, PeerDirection::Inbound) }
          rescue ex
            break unless @running
            Log.warn { "p2p_accept_error error=#{ex.message}" }
          end
        end
      end

      private def connect_outbound(address : String) : Nil
        return if @peer_manager.banned?(address)
        return unless @peer_manager.can_accept(PeerDirection::Outbound, address)

        host, port = parse_host_port(address)
        socket = TCPSocket.new(host, port)
        handle_connection(socket, address, PeerDirection::Outbound)
      rescue ex
        Log.warn { "p2p_connect_failed peer=#{address} error=#{ex.message}" }
      end

      private def handle_connection(socket : TCPSocket, address : String, direction : PeerDirection) : Nil
        peer = Peer.new(address, address, socket, direction)
        return unless @peer_manager.register(peer)

        begin
          unless perform_handshake(peer, direction)
            @peer_manager.record_misbehavior(address)
            return
          end

          peer.handshake_complete = true

          while @running
            message = Wire.read(socket)
            break unless message
            handle_message(peer, message)
          end
        ensure
          @peer_manager.disconnect(address)
          socket.close
        end
      end

      private def perform_handshake(peer : Peer, direction : PeerDirection) : Bool
        socket = peer.socket
        return false unless socket

        case direction
        when PeerDirection::Outbound
          send_handshake(peer)
          incoming = Wire.read(socket)
          return false unless incoming

          case incoming.type
          when "handshake"
            return false unless incoming.genesis_hash == @chain.genesis_hash
            send_handshake_ack(peer)
            true
          when "handshake_ack"
            true
          else
            false
          end
        else
          incoming = Wire.read(socket)
          return false unless incoming
          return false unless incoming.type == "handshake"
          return false unless incoming.genesis_hash == @chain.genesis_hash

          send_handshake_ack(peer)
          true
        end
      end

      private def send_handshake(peer : Peer) : Nil
        peer.send_message(Message.handshake(@chain.genesis_hash, @chain.height, @chain.tip.hash))
      end

      private def send_handshake_ack(peer : Peer) : Nil
        peer.send_message(Message.handshake_ack(@chain.height, @chain.tip.hash))
      end

      private def handle_message(peer : Peer, message : Message) : Nil
        address = peer.address
        case message.type
        when "inv"
          hashes = message.hashes || [] of String
          return unless @peer_manager.reputation.record_inv(address)

          hashes.each do |hash|
            next if @chain.has_block?(hash)

            peer.send_message(Message.get_block(hash))
          end
        when "getblock"
          hash = message.hash
          return unless hash

          block = @chain.block_by_hash(hash) || @orphan_pool.get(hash)
          if block
            peer.send_message(Message.block_payload(block))
          else
            peer.send_message(Message.reject("block not found"))
          end
        when "block"
          json = message.block
          return unless json

          block = Block.from_json(json)
          handle_incoming_block(block, address)
        when "ping"
          peer.send_message(Message.pong)
        end
      rescue ex
        Log.warn { "p2p_message_error peer=#{peer.address} error=#{ex.message}" }
        @peer_manager.record_misbehavior(peer.address)
      end

      private def parse_host_port(address : String) : Tuple(String, Int32)
        if address.includes?(':')
          host, port = address.split(':', limit: 2)
          {host, port.to_i32}
        else
          {address, @port}
        end
      end
    end
  end
end
