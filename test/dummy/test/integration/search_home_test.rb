# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SearchHomeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |account|
      account.password = "Password123!"
      account.password_confirmation = "Password123!"
      account.name = "Ada Admin"
    end
    @user.update!(name: "Ada Admin")
    sign_in @user
  end

  test "blank home shows the Flatpack search control" do
    get root_path
    assert_response :success
    assert_select "h1", text: /Search/
    assert_select "form[action='#{root_path}'][method=get]" do
      assert_select "input[name=q]", count: 1
      assert_select "[data-controller*='flat-pack--search-input']", count: 1
      assert_select "[data-controller*='flat-pack--search-input'][class*='max-w-none']", count: 1
      assert_select "[data-controller*='flat-pack--search-input'][class*='w-full']", count: 1
      refute_select "[class*='max-w-lg']"
      assert_select "input[class*='search-padding-y-lg']", count: 1
      refute_select "button[type=submit]"
    end
    refute_match "Look up", response.body
    refute_match "Ada Admin", response.body
  end

  test "home page stamps the rounded Flatpack theme on html and body" do
    get root_path

    assert_response :success
    assert_select 'html[data-theme="rounded"]', count: 1
    assert_select 'body[data-theme="rounded"]', count: 1
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
  end

  test "home links to the people, group, and title-first demos" do
    get root_path

    assert_response :success
    assert_select "a[href='#{people_path}']", text: /Just people/
    assert_select "a[href='#{instant_people_path}']", text: /As you type/
    assert_select "a[href='#{groups_path}']", text: /In a group/
    assert_select "a[href='#{title_first_path}']", text: /Title first/
  end

  test "trigram search finds a person" do
    get root_path, params: { q: "Ada" }
    assert_response :success
    assert_select "input[name=q][value=Ada]"
    assert_match "Ada Admin", response.body
  end

  test "vector search finds a page by meaning" do
    root = DummyAccess.bootstrap_workspace!(name: "Home Search Workspace", actor: @user)
    page = Page.create!(title: "Refunds", body: "How to request a refund when a charge looks wrong.")
    DummyAccess.record_under_workspace!(page, actor: @user, workspace_name: "Home Search Workspace")
    RecordingStudioSearch::DocumentEmbedder.call(
      searchable_type: "Page",
      searchable_id: page.id,
      recording_id: page.search_recording_id
    )
    switch_root!(root)

    get root_path, params: { q: "refund" }
    assert_response :success
    assert_match "Refunds", response.body
  end

  test "trigram search finds a note by title" do
    Note.create!(title: "Sticky reminder")

    get root_path, params: { q: "sticky" }
    assert_response :success
    assert_match "Sticky reminder", response.body
  end

  private

  def switch_root!(root)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: { root_recording_id: root.id, return_to: "/" }
    }
    assert_response :redirect
    # An engine request sticks its mount path onto the next main-app path helper.
    integration_session.instance_variable_set(:@controller, nil)
    integration_session.instance_variable_set(:@url_options, nil)
  end
end
