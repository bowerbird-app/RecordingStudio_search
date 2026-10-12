# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

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
    assert_select "[data-recording-studio-search--instant-search-frame-id-value='people_results']"
    assert_select "[data-recording-studio-search--instant-search-debounce-ms-value='200']"
    assert_select "input[name=q]", count: 1
    assert_select "[data-controller*='flat-pack--search-input']", count: 1
    assert_select "turbo-frame#people_results", count: 1
    assert_match "Type a little", response.body
    assert_match "Hits land here as you go.", response.body
    assert_match "Try Ada or hopper", response.body
    refute_match "Ada Admin", response.body
    refute_select "form[action='#{instant_people_path}']"
    refute_select "form[method=get]"
  end

  test "engine instant search finds an allowlisted person inside the turbo frame" do
    get recording_studio_search.instant_search_path, params: {
      q: "Ada",
      models: ["User"],
      frame_id: "people_results"
    }, headers: { "Turbo-Frame" => "people_results" }

    assert_response :success
    assert_select "turbo-frame#people_results"
    assert_match "Ada Admin", response.body
    assert_match "Name", response.body
    assert_match "Detail", response.body
    assert_select "th", text: "Name"
    assert_select "th", text: "Detail"
    assert_select "td", text: "Ada Admin"
    refute_match "<html", response.body
  end

  test "engine instant search ignores models that are not allowlisted" do
    Page.find_or_create_by!(title: "Refunds") do |page|
      page.body = "How to request a refund when a charge looks wrong."
    end

    get recording_studio_search.instant_search_path, params: {
      q: "refund",
      models: ["Page"],
      frame_id: "people_results"
    }

    assert_response :success
    assert_match "No luck", response.body
    assert_match "Try another word. Typos are fine.", response.body
    refute_match "Refunds", response.body
  end

  test "engine instant search ignores a second model mixed with an allowlisted one" do
    Note.find_or_create_by!(title: "Sticky reminder")

    get recording_studio_search.instant_search_path, params: {
      q: "Ada",
      models: ["User", "Note"],
      frame_id: "people_results"
    }

    assert_response :success
    assert_match "Ada Admin", response.body
    refute_match "Sticky reminder", response.body
  end

  test "blank query on the engine endpoint does not list everyone" do
    get recording_studio_search.instant_search_path, params: {
      q: "",
      models: ["User"],
      frame_id: "people_results"
    }

    assert_response :success
    assert_match "Type a little", response.body
    assert_match "Hits land here as you go.", response.body
    refute_match "Ada Admin", response.body
  end

  test "typed query with no people says no luck and still skips everyone" do
    get recording_studio_search.instant_search_path, params: {
      q: "zzzznope",
      models: ["User"],
      frame_id: "people_results"
    }, headers: { "Turbo-Frame" => "people_results" }

    assert_response :success
    assert_select "turbo-frame#people_results"
    assert_match "No luck", response.body
    assert_match "Try another word. Typos are fine.", response.body
    refute_match "Ada Admin", response.body
    refute_match "<html", response.body
  end
end
