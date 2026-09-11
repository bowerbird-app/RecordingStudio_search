# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PeopleSearchTest < ActionDispatch::IntegrationTest
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

  test "blank people page searches only User and does not list anyone" do
    get people_path

    assert_response :success
    assert_select "h1", text: /People/
    assert_select "form[action='#{people_path}'][method=get]" do
      assert_select "input[name=q]", count: 1
      assert_select "[data-controller*='flat-pack--search-input']", count: 1
    end
    assert_match "Type a name", response.body
    refute_match "Ada Admin", response.body
    refute_select "h2", text: /Pages/
    refute_select "h2", text: /Notes/
  end

  test "people search finds a person and ignores other models" do
    Note.find_or_create_by!(title: "Sticky reminder")
    Page.find_or_create_by!(title: "Refunds") do |page|
      page.body = "How to request a refund when a charge looks wrong."
    end

    get people_path, params: { q: "Ada" }

    assert_response :success
    assert_select "input[name=q][value=Ada]"
    assert_match "Ada Admin", response.body
    refute_match "Sticky reminder", response.body
    refute_match "Refunds", response.body
    refute_select "h2", text: /Pages/
    refute_select "h2", text: /Notes/
  end

  test "people search with a page word does not show pages" do
    Page.find_or_create_by!(title: "Refunds") do |page|
      page.body = "How to request a refund when a charge looks wrong."
    end

    get people_path, params: { q: "refund" }

    assert_response :success
    assert_match "Nobody by that name", response.body
    refute_match "Refunds", response.body
  end
end
