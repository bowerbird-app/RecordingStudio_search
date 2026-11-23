# frozen_string_literal: true

module RecordingStudioSearch
  # Registers named MCP copy when Recording Studio MCP is loaded.
  # This gem does not depend on it. Hosts that skip MCP keep the UI and API only.
  # Search has no recordable type, so this module does not call register_type.
  module McpCopy
    TOOL_NAME = "search_workspace"
    ENDPOINT = Api::NAME
    TITLE = Api::QUERY_TITLE
    OUTPUT = "hits: each hit has type (the Ruby class name), id, and recording_id (or null)."
    INPUT = {
      "q" => { description: Api::Q_DESCRIPTION },
      "models" => { description: Api::MODELS_DESCRIPTION },
      "limit" => { description: Api::LIMIT_DESCRIPTION }
    }.freeze

    DESCRIPTION = <<~TEXT.tr("\n", " ").squeeze(" ").strip.freeze
      Searches allowlisted types in this workspace by the words each type is set up to search.
      Returns the closest matches as hits.
      Ranking is the same as instant search.
      A pgvector type ranks by embedding distance.
      It uses trigram ranking when embeddings are unavailable.
      It uses trigram ranking when the embedding call fails, or when vector search finds nothing.
      A trigram type ranks by full-text rank, then trigram similarity.
      Scores from different types are not merged.
      Use this when you do not know the record id and you need a word match.
      Use the general list tool when you know the type and you want filters or pages.
      You do not call another tool first.
      Required input is q, the words to search.
      A blank q, or a q that is only whitespace, returns no hits.
      Optional models keeps a subset of config.instant_search_models.
      Omit models to search every type in that allowlist.
      Each name is the short class name, the text after the last ::, or the full class name.
      Take those names from config.instant_search_models.
      This call does not return that list.
      A name that is not on the allowlist is ignored.
      A short name that matches two allowlisted types is ignored.
      The full class name selects that type.
      When a type's MCP name differs from its short class name, pass the full class name in models.
      Optional limit is the maximum hits for each type.
      The default is 20.
      A value below 1 becomes 1.
      A value above 20 becomes 20.
      A missing or non-numeric limit stays 20.
      limit is a top-N cap for each type.
      It is not paginated.
      There is no offset.
      Several types can return more than 20 hits in one response.
      Each hit has type, id, and recording_id.
      type is the Ruby class name.
      id is the record id.
      recording_id is the recording id, or null when that type has no recording id.
      A hit has no title and no snippet.
      Hits stay in this workspace.
      Trashed recordings are left out.
      Another workspace is left out, even when its vectors are closer.
      A missing root returns no hits.
      The payload does not say whether pgvector or trigram produced a hit.
    TEXT

    module_function

    def register!
      # Isolated gem tests load this file without RecordingStudioMcp.
      # Dummy and hosts already have the gem. The engine calls this on
      # to_prepare; hosts do not. MCP 0.40.0 lets the same type and target
      # re-register copy, so a second call does not duplicate or raise.
      return unless available?

      mcp.register_tool(**search_tool_options)
    end

    def tool_names
      [TOOL_NAME]
    end

    def search_tool_options
      {
        name: TOOL_NAME,
        endpoint: ENDPOINT.to_sym,
        title: TITLE,
        description: DESCRIPTION,
        input: INPUT,
        output: OUTPUT
      }
    end

    def available?
      mcp_loaded? && endpoint_registered?
    end

    def mcp_loaded?
      mcp&.respond_to?(:register_tool)
    end

    def mcp
      return unless defined?(::RecordingStudioMcp)

      ::RecordingStudioMcp
    end

    def endpoint_registered?
      defined?(::RecordingStudioApi) &&
        ::RecordingStudioApi.respond_to?(:registered_endpoint) &&
        ::RecordingStudioApi.registered_endpoint(ENDPOINT).present?
    end
  end
end
