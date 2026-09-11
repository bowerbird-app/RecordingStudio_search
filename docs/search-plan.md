# RecordingStudio_search — implementation plan

Canonical copy of the search addon plan. Scope: this gem only. Do not wire Support `/help` or other host apps in the first delivery.

## What we are building

A reusable Rails engine that adds Postgres search to any ActiveRecord model a host opts in:

1. Trigram / full-text search (`pg_trgm` + generated `tsvector`) — default, no AI.
2. Vector / semantic search (`pgvector` + embeddings) — optional per model, with automatic fallback to trigram when embeddings fail or return nothing.

Hosts choose per model. Installing the gem does not change host tables. Hosts run generators to enable search on each model.

## Decisions

- Search lives in this gem, not inside RecordingStudio_support.
- First release does not integrate Support UI or routes.
- Do not use Elasticsearch / Searchkick.
- Keyword cache rows and embedding rows are ordinary tables, not Recordings or recordables.
- Embeddings are always in a gem-owned polymorphic table. Do not add embedding columns to the searchable model.
- For recordables, upsert embeddings by optional `recording_id`.
- Use `recording_studio_ai` for embeddings when possible; allow an injectable `embedding_client`. Do not hard-code provider SDKs or API keys here.
- If `RecordingStudioAI::Embeddings.create!` is missing, hosts inject `embedding_client`.
- Blank `Model.search("")` returns the unchanged relation (including any incoming scope).
- `against:` may be a column list or `{ column => "A"|"B"|"C"|"D" }` weights.
- Vector dimensions freeze at the first pgvector migration from `config.embedding_dimensions`.

## Per-model backends

| Backend | Meaning |
|---|---|
| `:pg_trgm` | Full-text + typo-tolerant trigram search on the model’s table only |
| `:pgvector` | Semantic search via embeddings; also keeps trigram schema so search can fall back |

## Fallback (`:pgvector` only)

| Condition | Behaviour |
|---|---|
| Embedding call fails or returns empty | Trigram results + `Rails.logger.warn` |
| Embedding succeeds but no document hits | Trigram results + `Rails.logger.warn` |
| Embedding succeeds with hits | Vector hits only — do not merge trigram hits |

## Schema

- Core install: `recording_studio_search_queries` (JSON embeddings so trigram-only hosts never need `vector`).
- `searchable_pg_trgm`: `search_vector` + GIN / trigram indexes on the model table.
- First `searchable_pgvector`: enable `vector`, create `recording_studio_search_documents` with `vector(N)`.

## Public API

```ruby
include RecordingStudioSearch::Searchable
searchable backend: :pg_trgm, against: %i[name email]
searchable backend: :pgvector, against: { title: "A", body: "D" }, recording_id: :recording_id

Model.search("refund policy")
Model.published.search(q)                              # keeps the scope
RecordingStudioSearch.search(Model, q)                 # => Relation
RecordingStudioSearch.search(Model.published, q)       # => Relation
RecordingStudioSearch.search([ModelA, ModelB], q)      # => { ModelA => Relation, ModelB => Relation }
RecordingStudioSearch.embed_later(record)
```

Jobs: `RecordingStudioSearch::EmbedDocumentJob`.

## Implementation phases

- Phase 0 — repository skeleton (this repo, renamed from the gem template)
- Phase 1 — trigram backend
- Phase 2 — vector backend, query cache, fallback, dummy proof (home mixed search; `/people` is `User.search` only)
- Phase 3 — backfill / re-embed tasks and search instrumentation

Support and other hosts consume the gem in separate work.
