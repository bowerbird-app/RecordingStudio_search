# Recording Studio Search

`recording_studio_search` adds **Postgres search** to any ActiveRecord model a host opts in:

1. **Trigram / full-text** (`pg_trgm` + a generated `tsvector`) — default, no AI.
2. **Vector / semantic** (`pgvector` + embeddings) — optional per model, with automatic fallback to trigram when embeddings fail or return nothing.

Installing the gem does not change host tables. Run generators for each model you care about.

This release does **not** wire Support `/help` or other host apps.

## Install

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.1"
gem "recording_studio_search", github: "bowerbird-app/RecordingStudio_search"
```

```bash
bundle install
bin/rails g recording_studio_search:install
bin/rails g recording_studio_search:searchable_pg_trgm User --against=name,email
bin/rails g recording_studio_search:searchable_pgvector SupportPage --against=title,body
bin/rails db:migrate
```

`install` writes the initializer and copies the **query-cache** migration. It does **not** enable the `vector` extension. That happens the first time you run `searchable_pgvector`.

Pending gem migrations can also be copied with `bin/rails g recording_studio_search:migrations`.

## Configuration

```ruby
# config/initializers/recording_studio_search.rb
RecordingStudioSearch.configure do |config|
  config.default_backend = :pg_trgm
  config.embedding_provider = :openai
  config.embedding_model = "text-embedding-3-small"
  config.embedding_dimensions = 1536
  config.embedding_distance = :cosine
  config.embedding_client = nil # nil → RecordingStudioAI embeddings when that API exists
  config.trigram_threshold = 0.3
  config.vector_result_limit = 50
end
```

Secrets stay in the host or in `recording_studio_ai`. This gem never ships API keys.

`embedding_client` signature: `->(text:, model:) { Array<Float> }`. Use it in tests and until `RecordingStudioAI::Embeddings.create!` ships.

If any registered model uses `:pgvector` and no client or AI embeddings API is available, boot logs a warning and those models search with trigram until you fix it.

Vector dimensions are frozen at the first pgvector migration from `config.embedding_dimensions`. Changing dimensions later needs a re-embed (`bin/rails recording_studio_search:reembed`), not a silent alter.

## Per-model backends

```ruby
class User < ApplicationRecord
  include RecordingStudioSearch::Searchable
  searchable backend: :pg_trgm, against: %i[name email]
end

class SupportPage < ApplicationRecord
  include RecordingStudioSearch::Searchable
  searchable backend: :pgvector, against: { title: "A", body: "D" }, recording_id: :recording_id
end
```

`against:` is a column list, or a Hash of column => Postgres weight `A`–`D` (title can outrank body). The list form keeps equal ranking. Weights change the generated `search_vector` (`setweight`) and trigram sort. Vector search still embeds one string; `A` fields are repeated so they matter more in the embedding.

```bash
bin/rails g recording_studio_search:searchable_pg_trgm User --against=name,email
bin/rails g recording_studio_search:searchable_pgvector SupportPage --against=title:A,body:D
```

If you already have an unweighted `search_vector`, drop and recreate that column (dummy `WeightPageSearchVector` is the shape). Then re-embed `:pgvector` models.

| Backend | Meaning |
|---|---|
| `:pg_trgm` | Full-text + typo-tolerant trigram search on that model's table |
| `:pgvector` | Semantic search via embeddings; **also** keeps trigram schema so search can fall back |

`User.search("ada")` is trigram/FTS only.  
`SupportPage.search("refund")` uses embeddings; on failure or empty hits it uses trigram and logs a warning.

`Model.search("")` (or blank `q`) returns the **unchanged relation**. Scopes stick: `SupportPage.published.search(q)` and `RecordingStudioSearch.search(SupportPage.published, q)` search inside that relation.

`RecordingStudioSearch.search(Model, q)` is the same facade and returns an `ActiveRecord::Relation`.

Pass an array when a screen needs several types (for example Section + Page). That returns a **Hash** of model class => relation, in the order you passed, with each model using its own backend. Lists stay separate; scores are not merged across types.

```ruby
RecordingStudioSearch.search(User, "ada")
# => User::ActiveRecord_Relation

RecordingStudioSearch.search([User, SupportPage], "refund", limit: 20)
# => { User => relation, SupportPage => relation }

hits = RecordingStudioSearch.search([User, SupportPage], "refund")
hits[User]         # people
hits[SupportPage]  # pages
```

## One model, one page

`RecordingStudioSearch.search([User, Page, Note], q)` is for a mixed list. A host page can call **one** model and skip the rest:

```ruby
class PeopleController < ApplicationController
  def index
    @q = params[:q].to_s
    @people = @q.present? ? User.search(@q, limit: 20) : User.none
  end
end
```

`User.search` and `RecordingStudioSearch.search(User, q)` are the same relation. Blank `q` returns the **unchanged** relation (everyone), so a lookup screen should use `User.none` when the box is empty.

The dummy app proves this at `/people` (home → **Just people**). That page never asks Page or Note. `/groups` searches inside a mailbox (`User.where(...).search`). `/title-first` ranks a title hit above a body hit.

## Data

Keyword cache rows and embedding rows are ordinary tables, not Recordings.

- Trigram columns (`search_vector` + GIN / trigram indexes) live on the **model table**, owned by `searchable_pg_trgm` (and by `searchable_pgvector`, which also ensures trigram). Safe for immutable recordables: each new snapshot row gets a fresh computed vector on insert.
- Embeddings live in gem-owned `recording_studio_search_documents` (`searchable_type` + `searchable_id`). **Do not** add `embedding` columns to the model. Optional `recording_id` upserts the stable Recording Studio identity so later snapshots do not orphan vectors.
- Query embeddings live in `recording_studio_search_queries` as JSON so trigram-only hosts never need the `vector` extension.

## Fallback (`:pgvector` only)

| Condition | Behaviour |
|---|---|
| Embedding call fails or returns empty | Trigram results + `Rails.logger.warn` |
| Embedding succeeds but no document hits | Trigram results + `Rails.logger.warn` |
| Embedding succeeds with hits | **Vector hits only** — not merged with trigram |

## Background embedding

`RecordingStudioSearch::EmbedDocumentJob` runs after create/update on `:pgvector` models. You can also call `RecordingStudioSearch.embed_later(record)` from a host create/revise path.

The job is idempotent on the stable key (`recording_id` or searchable pair) plus `content_digest`. On failure it logs and leaves the document missing or stale; search falls back to trigram.

```bash
bin/rails recording_studio_search:backfill
bin/rails recording_studio_search:reembed
```

## Dummy app

Sign in at `/users/sign_in` with Recording Studio Users (`v0.11.0`): email, then password (`admin@admin.com` / `Password`). Home searches people, pages, and notes together. `/people` searches **only** `User` (`User.search`). `/groups` keeps an existing people scope. `/title-first` shows title `A` ranking above body `D`.

PostgreSQL 16 with `pg_trgm` and `vector`. Dummy embeddings use an injected client so you do not need AI keys.

## Requirements

- Ruby 3.3+
- Rails 8.1+
- Recording Studio 4.x (`~> 4.2`; dummy tag `v4.2.1`)
- PostgreSQL 16

## Documentation

The implementation plan lives in `docs/search-plan.md`. Engine conventions from the gem template remain in `docs/gem_template/`.
