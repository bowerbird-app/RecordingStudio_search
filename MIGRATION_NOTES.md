# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.3.0`)
- Accessible dummy tag `v0.11.2` and Root Switchable dummy tag `v0.5.1`
- Users dummy tag `v0.15.0` (Admin `v2.0.6` and Attachable `v0.7.4` as Users runtime deps)
- FlatPack dummy tag `v0.1.207`
- Accessible 0.8+ stores dependent grants on `recording_studio_accesses.depends_on_recording_id`. Copy that column if you bump Accessible past 0.7.
- `json` 2.x (`>= 2.21, < 3`) until Rails 8.1 can call json 3’s `JSON.parse`
- PostgreSQL 16 with `pg_trgm` (always) and `vector` (only if a host enables `:pgvector`)
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

`RecordingStudioSearch.search` accepts one model class or relation (returns a relation that keeps the incoming scope) or an array of classes (returns `{ Model => relation }` in input order). Hosts render each list themselves; this gem does not merge ranks across types. Dummy `/people` is the one-model shape (`User.search`). Dummy `/instant` is the same search through a Turbo Frame. Dummy `/groups` is scoped people search. Dummy `/title-first` is weighted page ranking.

## Instant search (0.4.0)

Off by default. Set `config.instant_search_models` (class names are safest at boot), mount `RecordingStudioSearch::Engine`, pin `controllers/recording_studio_search`, import Turbo, then copy `instant_search_field` plus `instant_search_results`. The engine show action is the results URL. Blank `q` is empty, not everyone. Models that are not allowlisted are ignored. The frame uses each model’s declared backend (`:pg_trgm` or `:pgvector`). New query strings still hit the embedding client once, then `recording_studio_search_queries`. Dummy `/instant` allowlists `User` only as a trigram proof. No Support `/help` wiring. See `docs/search-plan.md` Phase 4.

## Field weights

`against: %i[title body]` is equal ranking. `against: { title: "A", body: "D" }` uses Postgres `setweight` (`A`–`D`) on `search_vector` and scales trigram similarity the same way. Regenerating `searchable_pg_trgm` with `--against=title:A,body:D` writes that expression for new tables. Existing columns need drop-and-recreate (see dummy `WeightPageSearchVector`). Vector models re-embed after a weight change.

Query-cache embeddings are JSON so trigram-only hosts never load `vector`. Document embeddings use `vector(N)` frozen from `config.embedding_dimensions` at migrate time.

## Changing vector dimensions

1. Drop and recreate `recording_studio_search_documents.embedding` as `vector(new_n)` (or rebuild the table).
2. Update `config.embedding_dimensions`.
3. Run `bin/rails recording_studio_search:reembed`.

Do not rely on a silent `ALTER COLUMN`.

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
