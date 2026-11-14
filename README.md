# Recording Studio Search

`recording_studio_search` adds **Postgres search** to any ActiveRecord model a host opts in:

1. **Trigram / full-text** (`pg_trgm` + a generated `tsvector`) — default, no AI.
2. **Vector / semantic** (`pgvector` + embeddings) — optional per model, with automatic fallback to trigram when embeddings fail or return nothing.

Installing the gem does not change host tables. Run generators for each model you care about.

This release does **not** wire Support `/help` or other host apps.

## Install

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.13.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.41.0"
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
  config.instant_search_models = [] # e.g. [User] — required for the instant endpoint
end
```

`config.trigram_threshold` (default `0.3`) is Postgres `pg_trgm.similarity_threshold` for the `%` operator on each `against` column. A row matches when any of those columns is at least that similar to the query, or when `search_vector` matches `plainto_tsquery`. `ts_rank` and `similarity()` sort the matches. The threshold is set for that query and then restored.

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

`User.search("ada", unscoped: true)` is trigram/FTS only.  
`SupportPage.search("refund", actor: current_user, root: current_root_recording)` uses embeddings; on failure or empty hits it uses trigram and logs a warning.

Every search passes `actor:` and `root:` (the root recording the actor is in), or `unscoped: true`. Omitting both raises. The scope is recordings that actor can view under that root. Trashed recordings are left out. `unscoped: true` is for a model that is not a recording.

`Model.search("", actor:, root:)` returns that viewable relation. `Model.search("", unscoped: true)` returns the **unchanged relation**. Other scopes stick: `SupportPage.published.search(q, actor:, root:)` searches inside the published rows the actor can view.

`RecordingStudioSearch.search(Model, q, actor:, root:)` is the same facade and returns an `ActiveRecord::Relation`.

Pass an array when a screen needs several types (for example Section + Page). That returns a **Hash** of model class => relation, in the order you passed, with each model using its own backend. The same actor and root apply to each model. Lists stay separate; scores are not merged across types.

```ruby
RecordingStudioSearch.search(User, "ada", unscoped: true)
# => User::ActiveRecord_Relation

RecordingStudioSearch.search(
  [User, SupportPage],
  "refund",
  actor: current_user,
  root: current_root_recording,
  limit: 20
)
# => { User => relation, SupportPage => relation }

hits = RecordingStudioSearch.search(
  [User, SupportPage], "refund", actor: current_user, root: current_root_recording
)
hits[User]         # people, only when User recordings exist under that root
hits[SupportPage]  # pages the actor can view
```

## One model, one page

`RecordingStudioSearch.search([User, Page, Note], q)` is for a mixed list. A host page can call **one** model and skip the rest:

```ruby
class PeopleController < ApplicationController
  def index
    @q = params[:q].to_s
    @people = @q.present? ? User.search(@q, limit: 20, unscoped: true) : User.none
  end
end
```

`User.search(..., unscoped: true)` and `RecordingStudioSearch.search(User, q, unscoped: true)` are the same relation. People are not recordings, so this lookup opts out of the access scope. Blank `q` with `unscoped: true` returns the **unchanged** relation (everyone), so a lookup screen should use `User.none` when the box is empty. A tree model passes the actor and the current root instead:

```ruby
Page.search(@q, actor: Current.actor, root: current_root_recording, limit: 20)
```

The dummy app proves this at `/people` (home → **Just people**). That page never asks Page or Note. `/groups` searches inside a mailbox (`User.where(...).search`). `/title-first` ranks a title hit above a body hit.

## Instant search (opt-in)

Debounced Flatpack Search chrome that fills a Turbo Frame. Same `Model.search` / `RecordingStudioSearch.search` as a full-page search: **trigram or vector**, whichever the model declared. Allowlist a `:pgvector` model and the frame uses embeddings (with the usual trigram fallback). The UI is **not** injected on boot. Scores are **not** merged across models.

Document vectors already live in `recording_studio_search_documents`. The **query** string still needs an embedding the first time that exact keyword is seen; repeats come from `recording_studio_search_queries`. Debounce (default 200ms) fires once per settled prefix, so typing `Ada` can embed `A`, `Ad`, and `Ada` unless those rows are already cached.

1. Mount the engine (`bin/rails g recording_studio_search:install` does this).
2. Allowlist models. Only these may be searched via the engine endpoint. Prefer class **names** in the initializer so boot does not load models early:

```ruby
config.instant_search_models = ["Page"]
```

3. Pin `controllers/recording_studio_search` and `eagerLoadControllersFrom` it. Import Turbo (`import "@hotwired/turbo-rails"`).
4. Copy this pair onto a host page. First helper is the field. Second is the frame.

```erb
<%= recording_studio_search.instant_search_field(
      models: [Page],
      frame_id: "page_results",
      url: recording_studio_search.instant_search_path,
      param: :q,
      debounce_ms: 200
    ) %>
<%= recording_studio_search.instant_search_results(
      frame_id: "page_results",
      hits: @hits
    ) %>
```

On the host action, start with empty hits (`Page.none`). Do not call `Page.search("", unscoped: true)` for a blank box — that would list everyone. The engine show action does the same: blank `q` renders the empty frame, not the full table. Hits are Accessible-scoped to the current actor and `current_root_recording` (`:view`, trashed recordings left out). Blank actor, blank root, or a model with no recording is empty.

`url:` defaults to `InstantSearchesController#show` (`GET …/instant_search?models[]=Page&frame_id=…`). Pass a host path only when that action should render the frame instead. Requested models that are not allowlisted are ignored.

Override `app/views/recording_studio_search/_results.html.erb` if the default Name / Detail table is wrong for a type.

Static chrome on that partial (empty-state titles, column headers, and the
helper's default placeholder) ships as English Rails I18n under
`recording_studio.search` in the gem's `config/locales/en.yml`, looked up
through `RecordingStudio.t` (this gem's shipped keys only). When the active
locale has no translation, fallback comes from the loaded English (host
overrides included), then any caller `default:`, then the gem-shipped table
registered at boot. Requires Recording Studio `>= 6.1.0`. A plain default with
no interpolation is returned as a plain (non-html_safe) String, so views will
escape it. On a missing `_html` key (vs view `t` / `I18n.t` on recording_studio
v4.7.0): a plain String caller `default:` matches and stays unsafe; an Array
caller `default:` returns the same string but `RecordingStudio.t` marks it
html_safe while view `t` / `I18n.t` leave it unsafe. Hosts can override those
keys. Optional multi-model `results.collections.<demodulized_plural>` section
titles are host-only keys: they stay on view `t` / `I18n.t` with main's
`default:` the raw model-derived label. Pass `placeholder:` to
`instant_search_field` when the page should use its own prompt. Search result
rows stay untranslated — they are model data. `instant_search_collection_label`
still returns raw English; the results partial translates at render via
`instant_search_translated_collection_label`.

Dummy `/instant` (home → **As you type**) is the proof page: it allowlists `Page` so typing updates the frame and leaves the URL at `/instant`. Pages without a grant, and trashed pages, do not appear. `/people` passes `unscoped: true` on `User.search` because a person is not a recording. A clip lives in `docs/demo/` (`instant-search-demo.mp4` plus a text `instant-search-demo.mp4.b64` for fetchers that cannot keep the binary intact).

## API and MCP (`search.query`)

Agents and API clients should not rely on core list `q` (ILIKE). This gem registers one public endpoint when Recording Studio API is loaded:

- Name: `search.query`
- Path: `GET search/query`
- Handler: `InstantSearch.hits_for` after `access_grant.authorize!(role: :view)` on the request root

MCP lists registered endpoints. This gem does not add MCP tool code.

Pass `q`. Optionally pass `models` (allowlisted type names) and `limit` (default 20, max 20). `limit` is top-N, not paginated. Values below 1 become 1 and values above 20 become 20. A missing or non-numeric `limit` stays 20. Omit `models` to search every `config.instant_search_models` type. Ranking happens inside the request root before that top-N. Hits then stay on recordings the caller can view. A caller who can view two workspaces still does not see the other root, including when that root's vectors are closer. A caller without `:view` on the root is denied.

This gem does not depend on `recording_studio_api` at runtime. It is a development dependency so the dummy and gem tests can use the real module. Hosts that already mount that gem get the endpoint from this engine's `to_prepare` registration.

## Data

Keyword cache rows and embedding rows are ordinary tables, not Recordings.

- Trigram columns (`search_vector` + GIN / trigram indexes) live on the **model table**, owned by `searchable_pg_trgm` (and by `searchable_pgvector`, which also ensures trigram). Safe for immutable recordables: each new snapshot row gets a fresh computed vector on insert.
- Embeddings live in gem-owned `recording_studio_search_documents` (`searchable_type`, `searchable_id`, optional `recording_id`, and `root_recording_id`). **Do not** add `embedding` columns to the model. `recording_id` upserts the stable Recording Studio identity so later snapshots do not orphan vectors. `root_recording_id` is the root of that recording's tree. Vector search filters on root, type, and the actor's viewable recording ids inside SQL before ordering by distance and applying `LIMIT`. Pass `actor:` and `root:` (`search.query` uses the request actor and root). `root_recording_id:` still selects the tenant for the vector index. A row the actor cannot view, and a trashed recording, are left out before that top-N.
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

Sign in at `/users/sign_in` with Recording Studio Users (`v0.29.0`): email, then password (`admin@admin.com` / `Password123!`). Home searches people, pages, and notes together. `/people` searches **only** `User` (`User.search`). `/instant` types into a Turbo Frame of pages the signed-in person can view. `/groups` keeps an existing people scope. `/title-first` shows title `A` ranking above body `D` for pages they can view.

PostgreSQL 16 with `pg_trgm` and `vector`. pgvector 0.8 or newer walks a filtered HNSW index iteratively (`strict_order`). Older pgvector still filters before the limit and sorts those rows exactly. The cosine HNSW index stays either way. Dummy embeddings use an injected client so you do not need AI keys.

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

## Requirements

- Ruby 3.3+
- Rails 8.1+
- Recording Studio `>= 6.1.0` (dummy tag `v6.13.0`, FlatPack `v0.1.366`). Core 6.9+ stores `root_recording_id` on events. Copy that migration before writing events. Scoped search needs Recording Studio `>= 6.13.0`.
- Accessible `>= 0.41.0` on the host (dummy tag `v0.41.0`) for `authorized_recording_ids`. Missing Accessible, or an authorization service that does not support that query, returns no hits.
- PostgreSQL 16 and pgvector. 0.8 or newer (CI image `pgvector/pgvector:0.8.1-pg16`) for iterative filtered HNSW scans. Older pgvector returns the same tenant rows with an exact filtered scan.

## Documentation

The implementation plan lives in `docs/search-plan.md`. Engine conventions from the gem template remain in `docs/gem_template/`.
