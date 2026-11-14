# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `>= 6.1.0` (dummy GitHub tag `v6.13.0`). Core 6.9+ needs `recording_studio_events.root_recording_id`. Copy `20261114090000_add_root_recording_id_to_recording_studio_events` before writing events. Accessible 0.41 needs Recording Studio `>= 6.13.0`.
- Accessible dummy tag `v0.41.0` (`authorized_recording_ids`) and Root Switchable dummy tag `v0.15.0`
- Users dummy tag `v0.29.0` (Admin `v2.13.0`, Attachable `v0.23.0`, Logs `v0.7.4` as dummy runtime deps). Passwords shorter than 12 characters do not save.
- FlatPack dummy tag `v0.1.366` (core 6 needs FlatPack `>= 0.1.315`; Users 0.26 needs `>= 0.1.328`)
- Accessible 0.8+ stores dependent grants on `recording_studio_accesses.depends_on_recording_id`. Copy that column if you bump Accessible past 0.7.
- `json` 2.x (`>= 2.21, < 3`) until Rails 8.1 can call json 3’s `JSON.parse`
- PostgreSQL 16 with `pg_trgm` (always) and `vector` (only if a host enables `:pgvector`). pgvector 0.8 or newer runs filtered HNSW scans iteratively. Older pgvector still filters before the limit, with an exact scan. CI uses `pgvector/pgvector:0.8.1-pg16`.
- Public RubyGems and GitHub access for dependency installation

## First install

```bash
bundle install
bin/rails g recording_studio_search:install
bin/rails g recording_studio_search:searchable_pg_trgm User --against=name,email
bin/rails db:migrate
```

Enable vector search later:

```bash
bin/rails g recording_studio_search:searchable_pgvector SupportPage --against=title,body
bin/rails db:migrate
```

Declare matching `searchable backend:` on each model. Boot warns if the DSL and schema disagree.

`RecordingStudioSearch.search` accepts one model class or relation (returns a relation that keeps the incoming scope) or an array of classes (returns `{ Model => relation }` in input order). Hosts render each list themselves; this gem does not merge ranks across types. Every call passes `actor:` and `root:`, or `unscoped: true`. Dummy `/people` is the one-model shape (`User.search(..., unscoped: true)`), because a person is not a recording. Dummy `/instant` and `search.query` scope pages with `authorized_recording_ids` under the current root. Dummy `/groups` keeps a mailbox scope and passes `unscoped: true`. Dummy `/title-first` ranks inside that same access scope. Dummy writes use `config.authorize_write` through Accessible; seeds bootstrap owner grants with `bootstrap_owner_access!`.

## Instant search (0.4.0)

Off by default. Set `config.instant_search_models` (class names are safest at boot), mount `RecordingStudioSearch::Engine`, pin `controllers/recording_studio_search`, import Turbo, then copy `instant_search_field` plus `instant_search_results`. The engine show action is the results URL. Blank `q` is empty, not everyone. Models that are not allowlisted are ignored. Hits need Accessible `:view` on the record's recording. The frame uses each model’s declared backend (`:pg_trgm` or `:pgvector`). New query strings still hit the embedding client once, then `recording_studio_search_queries`. Dummy `/instant` allowlists `Page`. No Support `/help` wiring. See `docs/search-plan.md` Phase 4.

## Interface text (0.5.0)

Static instant-search chrome (empty states, column titles, default placeholder) uses Rails I18n keys under `recording_studio.search` in the gem’s `config/locales/en.yml`. English output is unchanged. Override those keys in the host locale files to translate. No dependency on `recording_studio_internationalization`. Result row content stays model data.

## Interface text outside views (0.6.0)

Every gem `t(...)` call passes English `default:` so a host locale without a fallback never shows "translation missing". Multi-model collection section titles translate at render via `instant_search_translated_collection_label` (`recording_studio.search.results.collections.<demodulized_plural>`, default the raw English from `instant_search_collection_label`). Public collection labels and result rows stay raw model data. English output is unchanged.

## English fallback via RecordingStudio.t (0.7.0)

Instant-search chrome uses `RecordingStudio.t` for this gem's shipped
`recording_studio.search.*` keys only. The engine registers
`config/locales/en.yml` with `RecordingStudio::Translation.register_shipped_english`
at boot. Fallback comes from the loaded English, host overrides included;
hand-copied English `default:` on shipped keys is gone. Optional collection
section titles stay on view `t` / `I18n.t` with main's `default:` the raw
model-derived label (host-only keys). Host or other-namespace lookups stay on
`I18n.t` with main's `default:`. Requires Recording Studio `>= 4.2, < 7`. English
output is unchanged. A plain default with no interpolation is returned as a
plain (non-html_safe) String, so views will escape it. On a missing `_html`
key (vs view `t` / `I18n.t` on recording_studio v4.7.0): a plain String caller
`default:` matches and stays unsafe; an Array caller `default:` returns the
same string but `RecordingStudio.t` marks it html_safe while view `t` /
`I18n.t` leave it unsafe.

## Field weights

`against: %i[title body]` is equal ranking. `against: { title: "A", body: "D" }` uses Postgres `setweight` (`A`–`D`) on `search_vector` and scales trigram similarity the same way. Regenerating `searchable_pg_trgm` with `--against=title:A,body:D` writes that expression for new tables. Existing columns need drop-and-recreate (see dummy `WeightPageSearchVector`). Vector models re-embed after a weight change.

Query-cache embeddings are JSON so trigram-only hosts never load `vector`. Document embeddings use `vector(N)` frozen from `config.embedding_dimensions` at migrate time.

## Changing vector dimensions

1. Drop and recreate `recording_studio_search_documents.embedding` as `vector(new_n)` (or rebuild the table).
2. Update `config.embedding_dimensions`.
3. Run `bin/rails recording_studio_search:reembed`.

Do not rely on a silent `ALTER COLUMN`.

## Tenant vector prefilter (0.11.0)

`recording_studio_search_documents` stores `root_recording_id` (the recording tree root) next to `searchable_type`. Embed and upsert write both. Vector search filters on root, type, and `authorized_recording_ids` inside SQL before `ORDER BY` distance `LIMIT`.

pgvector 0.8+ sets `hnsw.iterative_scan = strict_order` for that statement, with `hnsw.max_scan_tuples = 100000` and `hnsw.scan_mem_multiplier = 2`, and keeps the cosine HNSW index. Older pgvector turns index scans off for that statement and sorts the filtered rows. Results stay inside the tenant either way.

Hosts that already generated the documents table run:

```sql
ALTER TABLE recording_studio_search_documents
  ADD COLUMN root_recording_id uuid;

UPDATE recording_studio_search_documents AS documents
SET root_recording_id = COALESCE(recordings.root_recording_id, recordings.id)
FROM recording_studio_recordings AS recordings
WHERE documents.recording_id = recordings.id
  AND documents.root_recording_id IS NULL;

CREATE INDEX index_rss_documents_on_root_and_type
  ON recording_studio_search_documents (root_recording_id, searchable_type);
```

`searchable_pgvector` includes the column and index for a new table. The dummy app migration `20261114120000_add_root_recording_id_to_recording_studio_search_documents` is the same backfill. A second run does not replace a root that is already set.

`RecordingStudioSearch.search` takes `actor:`, `root:`, and `root_recording_id:`. `InstantSearch.hits_for` takes `actor:` and `root:` and uses that root's id as the vector tenant. `search.query` passes the request actor and root. Instant search without an actor or root returns nothing.

## Access scope (0.12.0)

No migration. `Model.search` and `RecordingStudioSearch.search` take `actor:` and `root:` (the root recording). Hits are recordings that actor can view under that root. The filter is one subquery from `RecordingStudioAccessible.authorized_recording_ids`, with `trashed_at` removed, and `LIMIT` is on that same statement. Vector search applies the same recording ids before the distance `LIMIT`.

`authorized_recording_ids_supported?` must be true. When it is false the id method raises, and search returns no rows.

`unscoped: true` is the opt-out for a model that is not on the tree. Omitting both the actor/root pair and `unscoped: true` raises.

```ruby
Page.search("refund", actor: current_user, root: current_root_recording, limit: 20)
User.search("ada", limit: 20, unscoped: true)
```

Install Accessible `>= 0.41.0` and Recording Studio `>= 6.13.0`.

## Trigram indexes and search limit (0.10.1)

No migration. Trigram search filters with `column % query` (pg_trgm similarity) or `search_vector @@ plainto_tsquery`, so the GIN indexes can be used. `config.trigram_threshold` is applied as `pg_trgm.similarity_threshold` for that query and then restored. Ranking is still `ts_rank`, then `similarity()`. `GET search/query` clamps `limit` to 1..20. The default stays 20.

## Verification

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

```bash
cd test/dummy
bin/dev
```

Sign in at `/users/sign_in` and search from `/`.
