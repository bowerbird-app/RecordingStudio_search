# frozen_string_literal: true

require "rails/generators"

module RecordingStudioSearch
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioSearch: initializer and core query-cache migrations"

      def copy_initializer
        template "recording_studio_search_initializer.rb", "config/initializers/recording_studio_search.rb"
      end

      def copy_migrations
        invoke "recording_studio_search:migrations"
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end
    end
  end
end
