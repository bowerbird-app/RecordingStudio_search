# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require "active_job/test_helper"

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper
  end
end
