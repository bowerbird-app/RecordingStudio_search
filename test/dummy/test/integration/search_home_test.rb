# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SearchHomeTest < ActionDispatch::IntegrationTest
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

  test "blank home shows the Flatpack search control" do
    get root_path
    assert_response :success
    assert_select "h1", text: /Search/
    assert_select "[class*='text-center']", minimum: 1
    assert_select "form[action='#{root_path}'][method=get]" do
      assert_select "input[name=q]", count: 1
      assert_select "[data-controller*='flat-pack--search-input']", count: 1
      assert_select "[data-controller*='flat-pack--search-input'][class*='max-w-none']", count: 1
      assert_select "[data-controller*='flat-pack--search-input'][class*='w-full']", count: 1
      refute_select "[class*='max-w-lg']"
      assert_select "input[class*='search-padding-y-lg']", count: 1
      refute_select "button[type=submit]"
    end
    assert_includes response.body, "--search-padding-y-lg: 1.25rem"
    refute_match "Look up", response.body
    refute_match "Ada Admin", response.body
    refute_match "Sign out", response.body
    refute_match "Studio Workspace", response.body
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
    assert_match "People", response.body
  end

  test "vector search finds a page by meaning" do
    page = Page.create!(title: "Refunds", body: "How to request a refund when a charge looks wrong.")
    RecordingStudioSearch::DocumentEmbedder.call(
      searchable_type: "Page",
      searchable_id: page.id
    )

    get root_path, params: { q: "refund" }
    assert_response :success
    assert_match "Refunds", response.body
    assert_select "a[href='#{page_path(page)}']"
    assert_select "img[alt='Refunds'][class*='object-cover']"
  end

  test "trigram search finds a note by title" do
    Note.create!(title: "Sticky reminder")

    get root_path, params: { q: "sticky" }
    assert_response :success
    assert_match "Sticky reminder", response.body
  end

  test "search hits group people pages and notes in cards" do
    get root_path, params: { q: "Ada" }

    assert_response :success
    assert_select "h2", text: "People"
    assert_select "h2", text: "Pages"
    assert_select "h2", text: "Notes"
  end
end
