# frozen_string_literal: true

require "test_helper"

class UserTrigramSearchTest < ActiveSupport::TestCase
  setup do
    User.delete_all
    @ada = User.create!(name: "Ada Lovelace", email: "ada@example.com", password: "Password")
    @grace = User.create!(name: "Grace Hopper", email: "grace@hopper.test", password: "Password")
  end

  test "token match on name" do
    assert_equal ["Ada Lovelace"], User.search("Lovelace").map(&:name)
  end

  test "token match on email" do
    assert_equal ["Grace Hopper"], User.search("hopper.test").map(&:name)
  end

  test "typo tolerance on name" do
    names = User.search("Lovlace").map(&:name)
    assert_includes names, "Ada Lovelace"
  end

  test "blank query returns the unchanged relation" do
    assert_equal User.all.to_sql, User.search("").to_sql
    assert_equal User.all.to_sql, User.search("   ").to_sql
    assert_equal 2, User.search("").count
  end

  test "against fields ignore other columns" do
    refute_includes User.search("Password").map(&:id), @ada.id
  end

  test "limit is applied" do
    assert_equal 1, User.search("Lovelace", limit: 1).size
  end
end
