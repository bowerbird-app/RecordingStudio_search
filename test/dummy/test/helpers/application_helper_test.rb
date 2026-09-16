# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "page cover uses a named svg or the default" do
    assert_equal "/covers/refunds.svg", page_cover_path(Page.new(title: "Refunds"))
    assert_equal "/covers/page.svg", page_cover_path(Page.new(title: "No Art"))
  end

  test "page published on is a long date" do
    page = Page.create!(title: "Dated", body: "Body", created_at: Time.zone.parse("2026-09-16"))

    assert_equal "September 16, 2026", page_published_on(page)
  end
end
