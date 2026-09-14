# frozen_string_literal: true

module RecordingStudioSearch
  class InstantSearchHelper
    CONTROLLER = "recording-studio-search--instant-search"

    def initialize(view)
      @view = view
    end

    # Locked helper for opt-in instant search chrome.
    # Debounced typing requests +url+ (engine InstantSearchesController#show by default)
    # into the Turbo Frame named +frame_id+.
    def instant_search_field(
      models:,
      frame_id:,
      url: nil,
      param: :q,
      debounce_ms: 200,
      placeholder: "Search...",
      value: nil,
      size: :lg,
      max_width: :none
    )
      results_url = results_url_for(url, models, frame_id, param)

      @view.tag.div(
        **wrapper_attributes(results_url, frame_id, param, debounce_ms)
      ) do
        @view.render(
          FlatPack::Search::Component.new(
            name: param.to_s,
            value: value,
            placeholder: placeholder,
            max_width: max_width,
            size: size
          )
        )
      end
    end

    def instant_search_path(**options)
      engine_routes.instant_search_path(**options)
    end

    def instant_search_url(**options)
      engine_routes.instant_search_url(**options)
    end

    private

    def wrapper_attributes(results_url, frame_id, param, debounce_ms)
      {
        data: {
          controller: CONTROLLER,
          action: "input->#{CONTROLLER}#type",
          "#{CONTROLLER}-url-value": results_url,
          "#{CONTROLLER}-param-value": param.to_s,
          "#{CONTROLLER}-frame-id-value": frame_id.to_s,
          "#{CONTROLLER}-debounce-ms-value": debounce_ms.to_i
        }
      }
    end

    def results_url_for(url, models, frame_id, param)
      base = url.presence || instant_search_path
      extra = {
        models: Array(models).map { |model| InstantSearch.class_name(model) },
        frame_id: frame_id.to_s
      }
      extra[:param] = param.to_s unless param.to_s == "q"
      join_query(base, extra)
    end

    def join_query(url, extra)
      path, existing = url.to_s.split("?", 2)
      query = Rack::Utils.parse_nested_query(existing.to_s)
      query = query.merge(extra.stringify_keys)
      "#{path}?#{query.to_query}"
    end

    def engine_routes
      helpers = Rails.application.routes.url_helpers
      return helpers.recording_studio_search if helpers.respond_to?(:recording_studio_search)

      RecordingStudioSearch::Engine.routes.url_helpers
    end
  end
end
