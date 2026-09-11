# frozen_string_literal: true

require "test_helper"

class UsersAuthTest < ActionDispatch::IntegrationTest
  test "sign in is the Users gem email-first screen" do
    get new_user_session_path

    assert_response :success
    assert_match "Welcome back", response.body
    assert_select "input[name='user[email]']", count: 1
    assert_select "input[name='user[password]']", count: 0
    assert_match "Continue with email", response.body
    refute_match ">Login<", response.body
  end

  test "dummy importmap names Attachable with a top-level constant" do
    importmap = File.read(Rails.root.join("config/importmap.rb"))
    index_js = File.read(Rails.root.join("app/javascript/controllers/index.js"))

    assert_includes importmap, "::RecordingStudioAttachable::Engine.root"
    refute_includes importmap, "pin_all_from RecordingStudioAttachable::Engine"
    assert_includes index_js, "eagerLoadControllersFrom"
    assert_includes index_js, 'import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"'
  end

  test "email step continues to the Users password screen" do
    user = User.find_or_create_by!(email: "admin@admin.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Ada Admin"
    end

    post "/users/sign_in", params: { user: { email: user.email } }

    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_select "input[name='user[password]']", count: 1
    assert_match "Forgot your password?", response.body
  end
end
