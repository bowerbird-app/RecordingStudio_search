class Note < ApplicationRecord
  include RecordingStudioSearch::Searchable

  searchable backend: :pg_trgm, against: %i[title]
end
