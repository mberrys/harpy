require "http"

module Harpy
  class RateLimiter
    @buckets = {} of String => TokenBucket
    @mutex = Mutex.new

    def initialize(
      @max_tokens : Int32 = Config.rate_limit_max,
      @refill_seconds : Int32 = Config.rate_limit_window_seconds,
    )
    end

    def self.from_env : self
      new(Config.rate_limit_max, Config.rate_limit_window_seconds)
    end

    def allow?(client_key : String) : Bool
      @mutex.synchronize do
        bucket = @buckets[client_key]? || TokenBucket.new(@max_tokens, Time.utc)
        bucket.refill(@max_tokens, @refill_seconds)
        return false unless bucket.consume

        @buckets[client_key] = bucket
        true
      end
    end

    private struct TokenBucket
      property tokens : Int32
      property last_refill : Time

      def initialize(@tokens : Int32, @last_refill : Time)
      end

      def refill(max_tokens : Int32, refill_seconds : Int32)
        now = Time.utc
        elapsed = now - @last_refill
        return if elapsed.total_seconds <= 0

        intervals = (elapsed.total_seconds / refill_seconds).to_i
        return if intervals <= 0

        @tokens = Math.min(max_tokens, @tokens + intervals)
        @last_refill = @last_refill + (intervals * refill_seconds).seconds
      end

      def consume : Bool
        return false if @tokens <= 0

        @tokens -= 1
        true
      end
    end
  end

  class RateLimitHandler
    include HTTP::Handler

    def initialize(@limiter : RateLimiter)
    end

    def call(context : HTTP::Server::Context)
      request = context.request

      if request.method == "POST" && request.path == "/new-block"
        unless @limiter.allow?(client_key(request))
          context.response.status_code = 429
          context.response.content_type = "application/json"
          context.response.print(%({"error":"rate limit exceeded"}))
          return
        end
      end

      call_next(context)
    end

    private def client_key(request : HTTP::Request) : String
      if forwarded = request.headers["X-Forwarded-For"]?
        forwarded.split(",").first.strip
      elsif remote = request.remote_address
        remote.is_a?(Socket::IPAddress) ? remote.address : remote.to_s
      else
        "unknown"
      end
    end
  end
end
