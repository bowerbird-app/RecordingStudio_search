# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class GroupSearchesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Ada Admin"
    end
    @user.update!(name: "Ada Admin")
    User.find_or_create_by!(email: "ada@example.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Ada Lovelace"
    end
    User.find_or_create_by!(email: "grace@hopper.test") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Grace Hopper"
    end
    sign_in @user
  end

  test "blank group page waits for a name" do
    get groups_path

    assert_response :success
    assert_select "h1", text: /In this group/
    assert_select "form[action='#{groups_path}'][method=get]" do
      assert_select "input[name=q]", count: 1
      assert_select "input[name=group][value=everyone]", count: 1
    end
    assert_match "Pick a group, then type a name", response.body
    refute_match "Ada Lovelace", response.body
  end

  test "everyone search finds Ada in both mailboxes" do
    get groups_path, params: { q: "Ada", group: "everyone" }

    assert_response :success
    assert_match "Ada Admin", response.body
    assert_match "Ada Lovelace", response.body
  end

  test "example.com search keeps Ada Lovelace and drops the admin mailbox" do
    get groups_path, params: { q: "Ada", group: "example.com" }

    assert_response :success
    assert_match "Ada Lovelace", response.body
    refute_match "Ada Admin", response.body
    refute_match "Grace Hopper", response.body
  end

  test "hopper.test search finds Grace and not Ada" do
    get groups_path, params: { q: "Ada", group: "hopper.test" }

    assert_response :success
    assert_match "Nobody in this group", response.body
    refute_match "Ada Lovelace", response.body

    get groups_path, params: { q: "Grace", group: "hopper.test" }

    assert_response :success
    assert_match "Grace Hopper", response.body
    refute_match "Ada Lovelace", response.body
  end
end
