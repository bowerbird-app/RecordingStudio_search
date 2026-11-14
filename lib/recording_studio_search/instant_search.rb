# frozen_string_literal: true

module RecordingStudioSearch
  # Instant search: opt-in Flatpack field + Turbo Frame results.
  #
  # Locked host API:
  #   recording_studio_search.instant_search_field(
  #     models: [User],
  #     frame_id: "people_results",
  #     url: recording_studio_search.instant_search_path,
  #     param: :q,
  #     debounce_ms: 200
  #   )
  #   recording_studio_search.instant_search_results(frame_id: "people_results", hits: @hits)
  #
  # Engine InstantSearchesController#show is the default results URL.
  # Only +config.instant_search_models+ may be searched. Unknown models are ignored.
  # Blank +q+ returns empty hits, not Model.search("") (which would list everyone).
  # Hits are Accessible-scoped to +actor+ under +root+ inside the search statement.
  # Vector search prefilters by that root and by authorized recording ids before LIMIT.
  # Blank actor, blank root, missing Accessible, or a model with no recording is empty.
  module InstantSearch
    RESERVED_PARAMS = %w[models frame_id controller action format authenticity_token].freeze

    module_function

    def hits_for(requested, query, actor: nil, root: nil, limit: 20)
      models = allowed_models(requested)
      return empty_hits(models) if models.empty? || query.to_s.strip.empty?
      return empty_hits(models) if actor.blank? || root.blank?

      if models.one?
        search_model(models.first, query, actor: actor, root: root, limit: limit)
      else
        models.index_with { |model| search_model(model, query, actor: actor, root: root, limit: limit) }
      end
    end

    def search_model(model, query, actor:, root:, limit:)
      RecordingStudioSearch.search(
        model,
        query,
        actor: actor,
        root: root,
        limit: limit,
        root_recording_id: root_recording_id(root)
      )
    end

    def root_recording_id(root)
      root.respond_to?(:id) ? root.id : nil
    end

    def empty_hits(models)
      return {} if models.empty?
      return models.first.none if models.one?

      models.index_with(&:none)
    end

    def allowed_models(requested)
      allowlist = allowlisted_by_name
      Array(requested).filter_map { |item| allowlist[class_name(item)] }.uniq
    end

    def allowlisted_by_name
      Array(RecordingStudioSearch.configuration.instant_search_models).filter_map do |item|
        model = item.is_a?(Class) ? item : nil
        model ||= item.to_s.safe_constantize if item.present?
        next unless model.is_a?(Class)

        model
      end.index_by(&:name)
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
