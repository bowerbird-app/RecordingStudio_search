# frozen_string_literal: true

module RecordingStudioSearch
  # View helpers for opt-in instant search chrome.
  # Included through ApplicationHelper, so a host page calls +instant_search_field+
  # and +instant_search_results+ directly.
  module InstantSearchHelper
    CONTROLLER = "recording-studio-search--instant-search"

    # Debounced typing requests +url+ (engine InstantSearchesController#show by default)
    # into the Turbo Frame named +frame_id+.
    def instant_search_field(models:, frame_id:, **options)
      param = options.fetch(:param, :q)
      results_url = instant_search_results_url(options[:url], models, frame_id, param)
      debounce_ms = options.fetch(:debounce_ms, 200)
      tag.div(
        class: "w-full",
        **instant_search_wrapper_attributes(results_url, frame_id, param, debounce_ms)
      ) do
        instant_search_render_control(param, options)
      end
    end

    # Host-copyable Turbo Frame around +recording_studio_search/results+.
    def instant_search_results(frame_id:, hits:, query: nil)
      tag.turbo_frame(id: frame_id.to_s) do
        render("recording_studio_search/results", hits: hits, query: query)
      end
    end

    private

    def instant_search_render_control(param, chrome)
      render(
        FlatPack::Search::Component.new(
          name: param.to_s,
          value: chrome[:value],
          placeholder: chrome.fetch(:placeholder, instant_search_default_placeholder),
          max_width: chrome.fetch(:max_width, :none),
          size: chrome.fetch(:size, :lg)
        )
      )
    end

    def instant_search_default_placeholder
      RecordingStudio.t("recording_studio.search.instant.placeholder")
    end

    def instant_search_wrapper_attributes(results_url, frame_id, param, debounce_ms)
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

    def instant_search_results_url(url, models, frame_id, param)
      base = url.presence || instant_search_default_path
      extra = {
        models: Array(models).map { |model| InstantSearch.class_name(model) },
        frame_id: frame_id.to_s
      }
      extra[:param] = param.to_s unless param.to_s == "q"
      instant_search_join_query(base, extra)
    end

    def instant_search_join_query(url, extra)
      path, existing = url.to_s.split("?", 2)
      query = Rack::Utils.parse_nested_query(existing.to_s)
      query = query.merge(extra.stringify_keys)
      "#{path}?#{query.to_query}"
    end

    def instant_search_default_path(**)
      instant_search_engine_routes.instant_search_path(**)
    end

    def instant_search_engine_routes
      helpers = Rails.application.routes.url_helpers
      return helpers.recording_studio_search if helpers.respond_to?(:recording_studio_search)

      RecordingStudioSearch::Engine.routes.url_helpers
    end
  end
end
