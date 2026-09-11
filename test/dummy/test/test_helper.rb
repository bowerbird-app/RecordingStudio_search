# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require "active_job/test_helper"

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    def reset_users!
      RecordingStudioUser::OtpChallenge.delete_all
      RecordingStudioUser::Identity.delete_all
      RecordingStudioUser::Profile.delete_all
      User.delete_all
    end
  end
end
