# frozen_string_literal: true

require "rails/generators"

module RecordingStudioSearch
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioSearch: initializer and core query-cache migrations"

      class_option :mount_path,
                   type: :string,
                   default: "/recording_studio_search",
                   desc: "Route prefix used when mounting the instant search engine"

      def mount_engine
        route %(mount RecordingStudioSearch::Engine, at: "#{options[:mount_path]}")
      end

      def copy_initializer
        template "recording_studio_search_initializer.rb", "config/initializers/recording_studio_search.rb"
      end

      def add_importmap_entries
        importmap_path = destination_path("config/importmap.rb")
        return unless File.exist?(importmap_path)
        return if File.read(importmap_path).include?("controllers/recording_studio_search")

        append_to_file "config/importmap.rb", <<~RUBY

          pin_all_from RecordingStudioSearch::Engine.root.join("app/javascript/controllers/recording_studio_search"),
            under: "controllers/recording_studio_search",
            to: "controllers/recording_studio_search"
        RUBY

        wire_stimulus_controllers
      end

      def copy_migrations
        invoke "recording_studio_search:migrations"
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end

      private

      def wire_stimulus_controllers
        controllers_index_path = destination_path("app/javascript/controllers/index.js")
        return unless File.exist?(controllers_index_path)

        contents = File.read(controllers_index_path)
        return if contents.include?("controllers/recording_studio_search")

        unless contents.include?("eagerLoadControllersFrom")
          prepend_to_file "app/javascript/controllers/index.js",
                          %(import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"\n)
        end

        append_to_file "app/javascript/controllers/index.js",
                       %(eagerLoadControllersFrom("controllers/recording_studio_search", application)\n)
      end

      def destination_path(relative)
        File.join(destination_root, relative)
      end
    end
  end
end
