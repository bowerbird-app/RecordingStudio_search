# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class WeightedPagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Ada Admin"
    end
    @user.update!(name: "Ada Admin")
    sign_in @user
    DummyAccess.bootstrap_workspace!(name: "Studio Workspace", actor: @user)
    DummyAccess.record_under_workspace!(
      Page.find_or_create_by!(title: "Widgets") { |page| page.body = "unrelated copy" },
      actor: @user
    )
    DummyAccess.record_under_workspace!(
      Page.find_or_create_by!(title: "Something else") { |page| page.body = "Widgets appear in the body only" },
      actor: @user
    )
  end

  test "blank title-first page waits for widgets" do
    get title_first_path

    assert_response :success
    assert_select "h1", text: /Title first/
    assert_select "form[action='#{title_first_path}'][method=get]" do
      assert_select "input[name=q]", count: 1
    end
    assert_match "Type widgets", response.body
    refute_match ">Widgets<", response.body
  end

  test "widgets ranks the titled page above the body-only page" do
    get title_first_path, params: { q: "widgets" }

    assert_response :success
    body = response.body
    title_at = body.index("Widgets")
    body_at = body.index("Something else")

    refute_nil title_at
    refute_nil body_at
    assert_operator title_at, :<, body_at
    assert_match "Title", body
    assert_match "Body", body
  end

  test "title-first search hides pages the signed-in person cannot view" do
    stranger = User.find_or_create_by!(email: "stranger-weights@example.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Stranger"
    end
    hidden = Page.find_or_create_by!(title: "Secret widgets") do |page|
      page.body = "widgets only this workspace should see"
    end
    DummyAccess.bootstrap_workspace!(name: "Weighted Private Workspace", actor: stranger)
    DummyAccess.record_under_workspace!(
      hidden,
      actor: stranger,
      workspace_name: "Weighted Private Workspace"
    )

    get title_first_path, params: { q: "widgets" }

    assert_response :success
    assert_match "Widgets", response.body
    refute_match "Secret widgets", response.body
  end
end

