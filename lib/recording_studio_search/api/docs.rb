# frozen_string_literal: true

module RecordingStudioSearch
  module Api
    QUERY_TITLE = "Search workspace"

    QUERY_DESCRIPTION = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
      Searches allowlisted types in this workspace by the words each type is set up to search.
      Returns the closest matches.
      Ranking is the same as instant search.
      A pgvector type ranks by embedding distance.
      It uses trigram ranking when embeddings are unavailable.
      It also uses trigram ranking when the embedding call fails, or when vector search finds nothing.
      A trigram type ranks by full-text rank, then trigram similarity.
      Scores from different types are not merged.
      Use this when you do not know the record id and you need a word match.
      Use the general list tool when you know the type and you want filters or pages.
      You do not call another tool first.
      Omit models to search every type in config.instant_search_models.
      Pass models to keep a subset of that allowlist.
      Each name is the short class name, the text after the last ::, or the full class name.
      Take those names from config.instant_search_models.
      This call does not return that list.
      A name that is not on the allowlist is ignored.
      A short name that matches two allowlisted types is ignored.
      The full class name selects that type.
      When a type's MCP name differs from its short class name, pass the full class name in models.
      q is the words to search.
      A blank q, or a q that is only whitespace, returns no hits.
      limit is the maximum hits for each type.
      The default is 20.
      A value below 1 becomes 1.
      A value above 20 becomes 20.
      A missing or non-numeric limit stays 20.
      limit is a top-N cap for each type.
      It is not paginated.
      There is no offset.
      Several types can return more than 20 hits in one response.
      The response key is hits.
      Each hit has type, id, and recording_id.
      type is the Ruby class name.
      id is the record id.
      recording_id is the recording id, or null when that type has no recording id.
      A hit has no title and no snippet.
      Hits are recordings you can view under the request root.
      Trashed recordings are left out.
      Another workspace you can view is left out, even when its vectors are closer.
      Without view on the request root, the call is denied.
      A missing root returns no hits.
      The payload does not say whether pgvector or trigram produced a hit.
    TEXT

    Q_DESCRIPTION = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
      Words to search. Required.
      A blank value, or a value that is only whitespace, returns no hits.
    TEXT

    MODELS_DESCRIPTION = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
      Allowlisted type names from config.instant_search_models. Optional.
      Omit this to search every allowlisted type.
      Pass the short class name, the text after the last ::, or the full class name.
      A short name is accepted only when one allowlisted type has it.
      Any other unknown name is ignored.
      This call does not return the allowlist.
      When a type's MCP name differs from its short class name, pass the full class name here.
    TEXT

    LIMIT_DESCRIPTION = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
      Maximum ranked hits for each type. Optional.
      Default 20.
      A value below 1 becomes 1.
      A value above 20 becomes 20.
      A missing or non-numeric value stays 20.
      This is a top-N cap for each type, not paginated.
      There is no offset.
      Several types together can return more than 20 hits.
    TEXT
  end
end
