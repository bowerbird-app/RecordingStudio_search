# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "minitest/mock"

class InstantPeopleSearchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Ada Admin"
    end
    @user.update!(name: "Ada Admin")
    sign_in @user
  end

  test "instant page wires the helper, stimulus attributes, and an empty frame" do
    get instant_people_path

    assert_response :success
    assert_select "h1", text: /As you type/
    assert_select "[data-controller='recording-studio-search--instant-search']", count: 1
    assert_select "[data-recording-studio-search--instant-search-param-value='q']"
    assert_select "[data-recording-studio-search--instant-search-frame-id-value='page_results']"
    assert_select "[data-recording-studio-search--instant-search-debounce-ms-value='200']"
    assert_select "input[name=q]", count: 1
    assert_select "[data-controller*='flat-pack--search-input']", count: 1
    assert_select "turbo-frame#page_results", count: 1
    assert_match "Type a little", response.body
    assert_match "Hits land here as you go.", response.body
    assert_match "Try widgets or refund", response.body
    refute_match "Refunds", response.body
    refute_select "form[action='#{instant_people_path}']"
    refute_select "form[method=get]"
  end

  test "engine instant search finds an allowlisted page the actor can view" do
    grant_refunds_page!

    get recording_studio_search.instant_search_path, params: {
      q: "refund",
      models: ["Page"],
      frame_id: "page_results"
    }, headers: { "Turbo-Frame" => "page_results" }

    assert_response :success
    assert_select "turbo-frame#page_results"
    assert_match "Refunds", response.body
    assert_match "Name", response.body
    assert_match "Detail", response.body
    assert_select "th", text: "Name"
    assert_select "th", text: "Detail"
    assert_select "td", text: "Refunds"
    refute_match "<html", response.body
  end

  test "engine instant search ignores models that are not allowlisted" do
    get recording_studio_search.instant_search_path, params: {
      q: "Ada",
      models: ["User"],
      frame_id: "page_results"
    }

    assert_response :success
    assert_match "No luck", response.body
    assert_match "Try another word. Typos are fine.", response.body
    refute_match "Ada Admin", response.body
  end

  test "engine instant search ignores a second model mixed with an allowlisted one" do
    grant_refunds_page!
    Note.find_or_create_by!(title: "Sticky reminder")

    get recording_studio_search.instant_search_path, params: {
      q: "refund",
      models: ["Page", "Note"],
      frame_id: "page_results"
    }

    assert_response :success
    assert_match "Refunds", response.body
    refute_match "Sticky reminder", response.body
  end

  test "blank query on the engine endpoint does not list pages" do
    grant_refunds_page!

    get recording_studio_search.instant_search_path, params: {
      q: "",
      models: ["Page"],
      frame_id: "page_results"
    }

    assert_response :success
    assert_match "Type a little", response.body
    assert_match "Hits land here as you go.", response.body
    refute_match "Refunds", response.body
  end

  test "typed query with no pages says no luck and still skips everyone" do
    get recording_studio_search.instant_search_path, params: {
      q: "zzzznope",
      models: ["Page"],
      frame_id: "page_results"
    }, headers: { "Turbo-Frame" => "page_results" }

    assert_response :success
    assert_select "turbo-frame#page_results"
    assert_match "No luck", response.body
    assert_match "Try another word. Typos are fine.", response.body
    refute_match "Refunds", response.body
    refute_match "<html", response.body
  end

  test "engine instant search is empty when Accessible is missing" do
    grant_refunds_page!

    without_accessible do
      get recording_studio_search.instant_search_path, params: {
        q: "refund",
        models: ["Page"],
        frame_id: "page_results"
      }

      assert_response :success
      refute_match "Refunds", response.body
      assert_match "No luck", response.body
    end
  end

  test "engine instant search is empty for a blank actor" do
    grant_refunds_page!

    hits = RecordingStudioSearch::InstantSearch.hits_for(["Page"], "refund", actor: nil)

    assert_equal 0, hits.count
  end

  test "engine instant search hides pages the actor cannot view" do
    grant_refunds_page!
    stranger = User.find_or_create_by!(email: "stranger-instant@example.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Stranger"
    end
    hidden = Page.find_or_create_by!(title: "Hidden refunds") do |page|
      page.body = "A refund note in another workspace."
    end
    DummyAccess.bootstrap_workspace!(name: "Instant Private Workspace", actor: stranger)
    DummyAccess.record_under_workspace!(
      hidden,
      actor: stranger,
      workspace_name: "Instant Private Workspace"
    )

    get recording_studio_search.instant_search_path, params: {
      q: "refund",
      models: ["Page"],
      frame_id: "page_results"
    }

    assert_response :success
    assert_match "Refunds", response.body
    refute_match "Hidden refunds", response.body
  end

  private

  def without_accessible
    RecordingStudioSearch::AccessibleScope.stub(:accessible?, false) { yield }
  end

  def grant_refunds_page!
    DummyAccess.bootstrap_workspace!(name: "Studio Workspace", actor: @user)
    page = Page.find_or_create_by!(title: "Refunds") do |record|
      record.body = "How to request a refund when a charge looks wrong."
    end
    DummyAccess.record_under_workspace!(page, actor: @user)
    RecordingStudioSearch::DocumentEmbedder.call(
      searchable_type: "Page",
      searchable_id: page.id,
      recording_id: page.search_recording_id
    )
    page
  end
end
