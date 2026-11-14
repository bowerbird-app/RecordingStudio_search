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
  # Hits are Accessible-scoped to +actor+ before ranking or limit.
  # Vector search prefilters by tenant root before that top-N.
  # Pass +root_recording_id+ to rank inside one root. Otherwise the roots
  # come from the recordings behind the Accessible relation.
  # Blank actor, missing Accessible, or a model with no recording is empty.
  module InstantSearch
    RESERVED_PARAMS = %w[models frame_id controller action format authenticity_token].freeze

    module_function

    def hits_for(requested, query, actor: nil, limit: 20, root_recording_id: nil)
      models = allowed_models(requested)
      return empty_hits(models) if models.empty? || query.to_s.strip.empty?

      scoped = models.map { |model| AccessibleScope.relation_for(model, actor) }
      if models.one?
        RecordingStudioSearch.search(
          scoped.first, query, limit: limit, root_recording_id: root_recording_id
        )
      else
        models.zip(scoped).to_h do |model, relation|
          [model, RecordingStudioSearch.search(relation, query, limit: limit, root_recording_id: root_recording_id)]
        end
      end
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
