# frozen_string_literal: true

module DummyEmbeddings
  AXES = {
    "ada" => 0,
    "lovelace" => 1,
    "refund" => 2,
    "password" => 3
  }.freeze

  def self.vector_for(text:, model: nil)
    values = Array.new(8, 0.01)
    downcased = text.to_s.downcase
    AXES.each do |word, index|
      values[index] = 1.0 if downcased.include?(word)
    end
    digest = Digest::SHA256.digest(text.to_s)
    4.upto(7) { |index| values[index] = digest.getbyte(index).to_f / 255.0 }
    values
  end
end

RecordingStudioSearch.configure do |config|
  config.default_backend = :pg_trgm
  config.embedding_provider = :openai
  config.embedding_model = "text-embedding-3-small"
  config.embedding_dimensions = 8
  config.embedding_distance = :cosine
  config.embedding_client = DummyEmbeddings.method(:vector_for)
  config.trigram_threshold = 0.3
  config.vector_result_limit = 50
  config.instant_search_models = ["User"]
end
