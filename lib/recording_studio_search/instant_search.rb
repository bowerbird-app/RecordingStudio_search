# frozen_string_literal: true

module RecordingStudioSearch
  # Instant search (slices 0–1): opt-in Turbo Frame results.
  #
  # Locked host API:
  #   recording_studio_search.instant_search_field(
  #     models: [User],
  #     frame_id: "people_results",
  #     url: recording_studio_search.instant_search_path, # engine InstantSearchesController#show
  #     param: :q,
  #     debounce_ms: 200
  #   )
  #   turbo_frame_tag "people_results" do
  #     render "recording_studio_search/results", hits: @hits
  #   end
  #
  # Only +config.instant_search_models+ may be searched on the engine endpoint.
  # Requested models that are missing from that allowlist are ignored.
  module InstantSearch
    RESERVED_PARAMS = %w[models frame_id controller action format authenticity_token].freeze

    module_function

    def allowed_models(requested)
      allowlist = allowlisted_by_name
      Array(requested).filter_map { |item| allowlist[class_name(item)] }.uniq
    end

    def allowlisted_by_name
      Array(RecordingStudioSearch.configuration.instant_search_models).filter_map { |item|
        model = item.is_a?(Class) ? item : nil
        model ||= item.to_s.safe_constantize if item.present?
        next unless model.is_a?(Class)

        model
      }.index_by(&:name)
    end

    def class_name(item)
      return item.name if item.is_a?(Class)

      item.to_s
    end

    def search_param(params)
      candidate = params[:param].to_s
      return "q" if candidate.blank? || RESERVED_PARAMS.include?(candidate)

      candidate
    end
  end
end
