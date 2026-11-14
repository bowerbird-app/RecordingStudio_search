# frozen_string_literal: true

require_relative "api/query"

module RecordingStudioSearch
  # Registers one public GET endpoint when Recording Studio API is loaded.
  # MCP advertises registered endpoints automatically. This gem adds no MCP tools.
  module Api
    NAME = "search.query"
    PATH = "search/query"
    VIEW_ROLE = :view
    DEFAULT_LIMIT = 20
    MAX_LIMIT = 20

    OPENAPI = {
      title: "Search - Query",
      summary: "Search - Query",
      description: "Ranked search of allowlisted types you can already view. " \
                   "Same ranking as instant search, not list q. Blank search returns no hits. " \
                   "Limit is top-N, not paginated.",
      tags: ["Search"],
      parameters: [
        {
          name: "q",
          in: "query",
          required: true,
          description: "Words to search. Blank returns no hits.",
          schema: { type: "string" }
        },
        {
          name: "models",
          in: "query",
          required: false,
          description: "Allowlisted type names. Omit to search every allowlisted type.",
          schema: { type: "array", items: { type: "string" } }
        },
        {
          name: "limit",
          in: "query",
          required: false,
          description: "Max ranked hits to return (top-N, not paginated). Default 20. Values outside 1..20 are clamped.",
          schema: { type: "integer" }
        }
      ]
    }.freeze

    INPUT_CONTRACT = {
      reject_unknown: false,
      fields: {
        q: { type: :string, required: true, description: "Words to search. Blank returns no hits." },
        models: {
          type: :array,
          required: false,
          description: "Allowlisted type names. Omit to search every allowlisted type."
        },
        limit: {
          type: :integer,
          required: false,
          description: "Max ranked hits to return (top-N, not paginated). Default 20. Values outside 1..20 are clamped."
        }
      }
    }.freeze

    class << self
      def register!
        return unless available?
        return if already_registered?

        RecordingStudioApi.register_endpoint(
          NAME,
          http_verb: :get,
          path: PATH,
          handler: Query,
          openapi: OPENAPI,
          input_contract: INPUT_CONTRACT
        )
        true
      end

      def available?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:register_endpoint) &&
          RecordingStudioApi.respond_to?(:registered_endpoint)
      end

      def already_registered?
        return false unless available?

        RecordingStudioApi.registered_endpoint(NAME).present?
      end
    end
  end
end
