module Harpy
  module Config
    extend self

    def genesis_difficulty : Int32
      if value = ENV["HARPY_DIFFICULTY"]?
        parsed = value.to_i
        return parsed if parsed >= 0
      end

      Block::DEFAULT_DIFFICULTY
    end
  end
end
