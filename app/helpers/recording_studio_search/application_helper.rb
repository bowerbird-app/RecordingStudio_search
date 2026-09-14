# frozen_string_literal: true

module RecordingStudioSearch
  module ApplicationHelper
    include ResultsHelper

    # Host API: recording_studio_search.instant_search_field(...)
    # See InstantSearchHelper and lib/recording_studio_search/instant_search.rb.
    def recording_studio_search
      @recording_studio_search_helper ||= InstantSearchHelper.new(self)
    end
  end
end
