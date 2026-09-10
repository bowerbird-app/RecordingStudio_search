class User < ApplicationRecord
  include RecordingStudioSearch::Searchable

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  searchable backend: :pg_trgm, against: %i[name email]
end
