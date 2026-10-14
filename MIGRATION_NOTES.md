# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.7` in the gemspec; dummy GitHub tag `v4.7.0`)
- Accessible dummy tag `v0.18.0` and Root Switchable dummy tag `v0.9.0`
- Users dummy tag `v0.21.0` (Admin `v2.3.0` and Attachable `v0.15.0` as Users runtime deps)
- FlatPack dummy tag `v0.1.213` (Attachable 0.12+ needs `>= 0.1.213`)
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
`I18n.t` with main's `default:`. Requires Recording Studio `~> 4.7`. English
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
