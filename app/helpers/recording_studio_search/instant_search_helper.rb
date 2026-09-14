# frozen_string_literal: true

module RecordingStudioSearch
  class InstantSearchHelper
    CONTROLLER = "recording-studio-search--instant-search"

    def initialize(view, routes = nil)
      @view = view_context_for(view)
      @routes = routes
    end

    # Locked helper for opt-in instant search chrome.
    # Debounced typing requests +url+ (engine InstantSearchesController#show by default)
    # into the Turbo Frame named +frame_id+.
    def instant_search_field(models:, frame_id:, **options)
      param = options.fetch(:param, :q)
      results_url = results_url_for(options[:url], models, frame_id, param)
      debounce_ms = options.fetch(:debounce_ms, 200)
      @view.tag.div(
        class: "w-full",
        **wrapper_attributes(results_url, frame_id, param, debounce_ms)
      ) do
        render_search_control(param, options)
      end
    end

    # Host-copyable Turbo Frame around +recording_studio_search/results+.
    def instant_search_results(frame_id:, hits:, query: nil)
      @view.tag.turbo_frame(id: frame_id.to_s) do
        @view.render("recording_studio_search/results", hits: hits, query: query)
      end
    end

    def instant_search_path(**)
      engine_routes.instant_search_path(**)
    end

    def instant_search_url(**)
      engine_routes.instant_search_url(**)
    end

    private

    def render_search_control(param, chrome)
      @view.render(
        FlatPack::Search::Component.new(
          name: param.to_s,
          value: chrome[:value],
          placeholder: chrome.fetch(:placeholder, "Try a name"),
          max_width: chrome.fetch(:max_width, :none),
          size: chrome.fetch(:size, :lg)
        )
      )
    end

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

    def view_context_for(view)
      return view.view_context if view.respond_to?(:view_context) && !view.respond_to?(:tag)

      view
    end

    def engine_routes
      return @routes if @routes.respond_to?(:instant_search_path)

      helpers = Rails.application.routes.url_helpers
      return helpers.recording_studio_search if helpers.respond_to?(:recording_studio_search)

      RecordingStudioSearch::Engine.routes.url_helpers
    end
  end
end
