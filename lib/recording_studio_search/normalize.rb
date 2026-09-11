# frozen_string_literal: true

module RecordingStudioSearch
  module Normalize
    module_function

    def keyword(text)
      text.to_s.unicode_normalize(:nfc).gsub(/\s+/, " ").strip.downcase
    end

    def digest(text)
      Digest::SHA256.hexdigest(keyword(text))
    end

    def content_digest(parts)
      Digest::SHA256.hexdigest(Array(parts).join("\n"))
    end

    def vector_literal(values)
      "[#{Array(values).map { |value| Float(value) }.join(',')}]"
    end
  end
end
