# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PagesShowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
      account.name = "Ada Admin"
    end
    sign_in @user
    @page = Page.create!(title: "Refunds", body: "How to request a refund when a charge looks wrong.")
  end

  test "show uses a larger title, cover image, and published date" do
    get page_path(@page)

    assert_response :success
    assert_select "h1", text: "Refunds"
    assert_includes response.body, "--page-title-h1-size: var(--text-5xl)"
    assert_match @page.created_at.to_date.to_fs(:long), response.body
    refute_match "Review the inline page content", response.body
    assert_select "img[alt='Refunds'][src='/covers/refunds.svg'][class*='object-cover']"
    assert_select "img[class*='h-full'][class*='w-full']"
    assert_match "How to request a refund when a charge looks wrong.", response.body
    refute_match "Sign out", response.body
    refute_match "Studio Workspace", response.body
  end

  test "show falls back to the default cover when no named art exists" do
    page = Page.create!(title: "Mystery Brief", body: "A page without named cover art.")

    get page_path(page)

    assert_response :success
    assert_select "img[alt='Mystery Brief'][src='/covers/page.svg']"
  end
end
