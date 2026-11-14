# frozen_string_literal: true

require "test_helper"

class UserTrigramSearchTest < ActiveSupport::TestCase
  setup do
    reset_users!
    @ada = User.create!(name: "Ada Lovelace", email: "ada@example.com", password: "Password123!")
    @grace = User.create!(name: "Grace Hopper", email: "grace@hopper.test", password: "Password123!")
  end

  test "token match on name" do
    assert_equal ["Ada Lovelace"], User.search("Lovelace", unscoped: true).map(&:name)
  end

  test "token match on email" do
    assert_equal ["Grace Hopper"], User.search("hopper.test", unscoped: true).map(&:name)
  end

  test "typo tolerance on name" do
    names = User.search("Lovlace", unscoped: true).map(&:name)
    assert_includes names, "Ada Lovelace"
  end

  test "blank query returns the unchanged relation" do
    assert_equal User.all.to_sql, User.search("", unscoped: true).to_sql
    assert_equal User.all.to_sql, User.search("   ", unscoped: true).to_sql
    assert_equal 2, User.search("", unscoped: true).count
  end

  test "against fields ignore other columns" do
    refute_includes User.search("Password", unscoped: true).map(&:id), @ada.id
  end

  test "limit is applied" do
    assert_equal 1, User.search("Lovelace", limit: 1, unscoped: true).size
  end

  test "search keeps an existing where scope" do
    scoped = User.where(email: "ada@example.com")

    assert_equal ["Ada Lovelace"], scoped.search("Lovelace", unscoped: true).map(&:name)
    assert_empty User.where(email: "grace@hopper.test").search("Lovelace", unscoped: true)
  end

  test "facade search keeps a relation scope" do
    scoped = User.where(email: "ada@example.com")

    assert_equal ["Ada Lovelace"], RecordingStudioSearch.search(scoped, "Lovelace", unscoped: true).map(&:name)
  end

  test "blank query keeps the incoming scope" do
    scoped = User.where(email: "ada@example.com")

    assert_equal scoped.to_sql, scoped.search("", unscoped: true).to_sql
    assert_equal 1, scoped.search("", unscoped: true).count
  end

  test "filter uses index operators and ranks matched rows" do
    sql = User.search("Lovelace", unscoped: true).to_sql
    where_sql, order_sql = sql.split("ORDER BY", 2)

    assert_match(/"users"\."name" % /, where_sql)
    assert_match(/"users"\."email" % /, where_sql)
    assert_match(/search_vector @@ plainto_tsquery\('english'/, where_sql)
    refute_match(/similarity\s*\(/, where_sql)
    assert_match(/similarity\s*\(/, order_sql)
    assert_match(/ts_rank\(/, order_sql)
    assert_includes sql, "pg_trgm.similarity_threshold=0.300000"
  end

  test "order by quotes the query" do
    sql = User.search("O'Brien", unscoped: true).to_sql

    assert_includes sql, "O''Brien"
  end

  test "trigram search uses a gin index" do
    plan = nil
    User.transaction do
      User.connection.execute("SET LOCAL enable_seqscan = off")
      plan = User.search("Lovelace", unscoped: true).explain.inspect
    end

    assert_match(
      /Bitmap Index Scan on index_users_on_(?:name_trgm|email_trgm|search_vector)/,
      plan
    )
  end

  test "configured threshold bounds trigram matches and full text still matches" do
    original = RecordingStudioSearch.configuration.trigram_threshold
    RecordingStudioSearch.configuration.trigram_threshold = 0.99

    assert_equal ["Ada Lovelace"], User.search("Lovelace", unscoped: true).map(&:name)
    refute_includes User.search("Lovlace", unscoped: true).map(&:name), "Ada Lovelace"
  ensure
    RecordingStudioSearch.configuration.trigram_threshold = original
  end

  test "search restores the caller's similarity threshold" do
    User.transaction do
      User.connection.execute("SET LOCAL pg_trgm.similarity_threshold = 0.85")
      User.search("Lovelace", unscoped: true).load
      current = User.connection.select_value("SHOW pg_trgm.similarity_threshold")

      assert_in_delta 0.85, current.to_f
    end
  end

  test "building the relation does not change the similarity threshold" do
    User.transaction do
      User.connection.execute("SET LOCAL pg_trgm.similarity_threshold = 0.77")
      User.search("Lovelace", unscoped: true).to_sql
      current = User.connection.select_value("SHOW pg_trgm.similarity_threshold")

      assert_in_delta 0.77, current.to_f
    end
  end

  test "a failed search restores the similarity threshold" do
    User.transaction do
      User.connection.execute("SET LOCAL pg_trgm.similarity_threshold = 0.81")
      assert_raises(ActiveRecord::StatementInvalid) do
        User.search("Lovelace", unscoped: true).where("1/0 = 1").load
      end
      current = User.connection.select_value("SHOW pg_trgm.similarity_threshold")

      assert_in_delta 0.81, current.to_f
    end
  end
end
