# frozen_string_literal: true

require_relative "api/docs"
require_relative "api/query"

module RecordingStudioSearch
  # Registers one public GET endpoint when Recording Studio API is loaded.
  # Named MCP copy for that endpoint lives in McpCopy (`search_workspace`).
  module Api
    NAME = "search.query"
    PATH = "search/query"
    VIEW_ROLE = :view
    DEFAULT_LIMIT = 20
    MAX_LIMIT = 20

    OPENAPI = {
      title: QUERY_TITLE,
      summary: QUERY_TITLE,
      description: QUERY_DESCRIPTION,
      tags: ["Search"],
      parameters: [
        {
          name: "q",
          in: "query",
          required: true,
          description: Q_DESCRIPTION,
          schema: { type: "string" }
        },
        {
          name: "models",
          in: "query",
          required: false,
          description: MODELS_DESCRIPTION,
          schema: { type: "array", items: { type: "string" } }
        },
        {
          name: "limit",
          in: "query",
          required: false,
          description: LIMIT_DESCRIPTION,
          schema: { type: "integer" }
        }
      ]
    }.freeze

    INPUT_CONTRACT = {
      reject_unknown: false,
      fields: {
        q: { type: :string, required: true, description: Q_DESCRIPTION },
        models: {
          type: :array,
          required: false,
          description: MODELS_DESCRIPTION
        },
        limit: {
          type: :integer,
          required: false,
          description: LIMIT_DESCRIPTION
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
