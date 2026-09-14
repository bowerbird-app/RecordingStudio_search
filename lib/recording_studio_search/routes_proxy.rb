# frozen_string_literal: true

module RecordingStudioSearch
  # Adds +instant_search_field+ to the mounted engine route helper
  # (+recording_studio_search+), which is the locked host API.
  module RoutesProxy
    def instant_search_field(...)
      raise NoMethodError, "undefined method `instant_search_field'" unless search_engine_proxy?

      InstantSearchHelper.new(scope, self).instant_search_field(...)
    end

    private

    def search_engine_proxy?
      routes.equal?(RecordingStudioSearch::Engine.routes)
    end
  end
end
