# frozen_string_literal: true

module RecordingStudioSearch
  # Adds +instant_search_field+ to the mounted engine route helper
  # (+recording_studio_search+), which is the locked host API.
  module RoutesProxy
    def instant_search_field(...)
      instant_search_helper.instant_search_field(...)
    end

    def instant_search_results(...)
      instant_search_helper.instant_search_results(...)
    end

    private

    def instant_search_helper
      raise NoMethodError, "undefined method for this routes proxy" unless search_engine_proxy?

      InstantSearchHelper.new(scope, self)
    end

    def search_engine_proxy?
      routes.equal?(RecordingStudioSearch::Engine.routes)
    end
  end
end
