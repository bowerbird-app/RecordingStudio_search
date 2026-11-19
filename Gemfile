# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_search.gemspec
gemspec

# recording_studio is not published to RubyGems; resolve the gemspec pin from GitHub.
gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"
gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"

gem "devise"
gem "puma"
gem "rack", ">= 3.2.8"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "recording_studio_accessible", "~> 0.55", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.55.0"
  gem "recording_studio_api", "~> 1.19", github: "bowerbird-app/RecordingStudio_api", tag: "v1.19.0"
  gem "recording_studio_icons", "~> 0.4", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.4.2"
  gem "recording_studio_logs", "~> 0.8", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.8.2"
  gem "recording_studio_metrics", "~> 0.9", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.9.2"
  gem "recording_studio_moveable", "~> 6.0", github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.0.3"
  gem "recording_studio_trashable", "~> 1.2", github: "bowerbird-app/RecordingStudio_trashable", tag: "v1.2.3"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
