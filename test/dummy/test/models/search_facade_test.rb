# frozen_string_literal: true

require "test_helper"

class SearchFacadeTest < ActiveSupport::TestCase
  setup do
    reset_users!
    Page.delete_all
    Note.delete_all
    RecordingStudioSearch::Document.delete_all
    RecordingStudioSearch::Query.delete_all

    @ada = User.create!(name: "Ada Lovelace", email: "ada@example.com", password: "Password")
    User.create!(name: "Grace Hopper", email: "grace@hopper.test", password: "Password")
    @refund = Page.create!(title: "Refunds", body: "How to request a refund when a charge looks wrong.")
    Page.create!(title: "Passwords", body: "Set a password you can remember.")
    Note.create!(title: "Sticky reminder")

    RecordingStudioSearch::DocumentEmbedder.call(
      searchable_type: "Page",
      searchable_id: @refund.id
    )
  end

  test "single model facade returns a relation" do
    result = RecordingStudioSearch.search(User, "Lovelace")

    assert_kind_of ActiveRecord::Relation, result
    assert_equal ["Ada Lovelace"], result.map(&:name)
    assert_equal User.search("Lovelace").to_sql, result.to_sql
  end

  test "array facade returns a hash of per-model relations" do
    result = RecordingStudioSearch.search([User, Page, Note], "refund", limit: 20)

    assert_equal [User, Page, Note], result.keys
    assert_kind_of ActiveRecord::Relation, result[User]
    assert_kind_of ActiveRecord::Relation, result[Page]
    assert_kind_of ActiveRecord::Relation, result[Note]
    assert_empty result[User]
    assert_equal ["Refunds"], result[Page].map(&:title)
    assert_empty result[Note]
  end

  test "array facade keeps each model on its own backend" do
    people = RecordingStudioSearch.search([User, Page], "Lovlace")

    assert_includes people[User].map(&:name), "Ada Lovelace"
    assert_empty people[Page]
  end

  test "array blank query returns each model's unchanged relation" do
    result = RecordingStudioSearch.search([User, Note], "")

    assert_equal User.all.to_sql, result[User].to_sql
    assert_equal Note.all.to_sql, result[Note].to_sql
  end
end
