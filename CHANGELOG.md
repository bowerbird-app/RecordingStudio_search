# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.1] - 2026-09-16

### Changed
- Dummy home centers the title, enlarges the search field, and groups People / Pages / Notes hits in cards
- Dummy page show uses a larger title, a cover image that fills its frame, and the published date instead of a subtitle
- Dummy page nav no longer shows Sign out or the workspace switcher

### Upgrade notes
- Host search screens are unchanged. If you copied the dummy home or page nav, take the centered title, larger search tokens, section cards, and the page show from `test/dummy`.

## [0.4.0] - 2026-09-14

### Added
- Opt-in instant search: Flatpack `Search` via `recording_studio_search.instant_search_field`
- `recording_studio_search.instant_search_results` Turbo Frame wrapper around `recording_studio_search/results`
- Engine `InstantSearchesController#show` for allowlisted `Model.search` / `RecordingStudioSearch.search`
- `config.instant_search_models` allowlist (empty by default; the endpoint ignores other models)
- Stimulus debounce controller that updates a Turbo Frame without a full page reload
- Blank `q` on the instant endpoint returns no rows (not everyone)
- Dummy `/instant` (“As you type”) proves typing updates `people_results` via `User.search` (trigram). Instant search is not limited to that backend: an allowlisted `:pgvector` model uses the same query cache and embedding path as `Model.search`

### Upgrade notes
- Instant search is off until you set `config.instant_search_models`, mount `RecordingStudioSearch::Engine`, and pin `controllers/recording_studio_search` in the host importmap (`eagerLoadControllersFrom`). Import Turbo.
- Re-run `bin/rails g recording_studio_search:install` or copy those lines by hand. Existing `Model.search` pages are unchanged.
- Copy the field + `instant_search_results` pair. The results URL is the engine show action (`recording_studio_search.instant_search_path`) unless you pass `url:`.
- Prefer class names in `instant_search_models` (`["User"]`) so the initializer does not load models at boot.
- Instant search on a `:pgvector` model still embeds each new query prefix (then caches it). Plan for first-type latency and embed cost; repeats stay in Postgres.

## [0.3.0] - 2026-09-10

First release of Recording Studio Search (renamed from the gem template).

### Added
- Per-model `searchable` DSL with `:pg_trgm` and `:pgvector` backends
- `Model.search` / `RecordingStudioSearch.search` with blank-query passthrough
- `RecordingStudioSearch.search([ModelA, ModelB], q)` returns a Hash of class => relation (no cross-type ranking)
- `searchable_pg_trgm` and `searchable_pgvector` generators (trigram columns on the model; embeddings in `recording_studio_search_documents`)
- `Model.search` / `RecordingStudioSearch.search` keep an existing ActiveRecord scope (class, `where`, or named scope)
- `against:` Hash of column => `A`–`D` weights (`setweight` on `search_vector`, weighted trigram sort; vector embed repeats `A` fields)
- Core query-cache migration without requiring the `vector` extension
- Injectable `embedding_client` and optional `RecordingStudioAI::Embeddings.create!` adapter
- `EmbedDocumentJob`, `embed_later`, digest-skip upserts, and `recording_id` identity for recordables
- Vector → trigram fallback with warnings; no merged result sets
- `recording_studio_search:backfill` and `recording_studio_search:reembed`
- Dummy `/people` searches only `User` (`User.search`) so a host can copy a one-model page
- Dummy `/groups` searches people inside a mailbox (`User.where(...).search`)
- Dummy `/title-first` ranks a title hit above a body hit on weighted `Page`
- Dummy host names Flatpack `rounded` (`FlatPack.configuration.default_theme`) and stamps `html data-theme="rounded"` without copying core `default_layout`
- Dummy home uses `FlatPack::Search::Component` (GET `q`) instead of a labeled text input plus Search button
- Dummy search control is full width (`max_width: :none`)
- Dummy Flatpack pin is `v0.1.177` so Search idle fill matches the live demo (`--surface-background-color`, not muted grey)
- Dummy GitHub pins: Recording Studio `v4.2.1`, Accessible `v0.9.1`, Root Switchable `v0.5.1`, Users `v0.11.0`, Admin `v2.0.2`, Attachable `v0.5.1`
- Dummy sign-in uses Recording Studio Users auth (`Welcome back`, email then password) instead of a host Devise Login card
- Gemspec requires `recording_studio ~> 4.2` (Accessible 0.7+ needs 4.2)
- Gemspec requires `json >= 2.21, < 3` so ActiveSupport’s `JSON.parse(string, options)` still works (json 3 only takes keyword options)

### Upgrade notes
- This is the first search release. Copy the initializer, run `recording_studio_search:install`, then enable each model with the searchable generators. Do not add embedding columns to host tables.
- Set `config.embedding_client` or wait for `RecordingStudioAI::Embeddings.create!`. Missing embeddings make `:pgvector` models search as trigram until fixed.
- Freeze `embedding_dimensions` before the first pgvector migration. To change dimensions, migrate the documents column yourself and run `recording_studio_search:reembed`.
- Dummy stamps `html data-theme="rounded"` because Recording Studio 4.2 puts the theme on `body`. Hosts that still key FlatPack off `html` can do the same. Do not vendor `recording_studio/default_layout`.
- Dummy Flatpack is `v0.1.177`. Search’s default fill is `--surface-background-color` from Flatpack 0.1.164; hosts still on 0.1.133 will see the older muted grey.
- Hosts on Recording Studio 4.1 need 4.2 before this gem. Accessible 0.8+ adds `depends_on_recording_id` on `recording_studio_accesses`; copy that migration when bumping past 0.7.
- Keep `json` on 2.x until Rails’ JSON decoder accepts json 3. Bundler will otherwise pull json 3.0 and query-cache writes fail.
- To weight fields, change `against:` to `{ title: "A", body: "D" }` (or `--against=title:A,body:D`) and replace the generated `search_vector` expression. List-form `against: %i[title body]` stays equal-weight; no migration. Re-embed after changing weights on a `:pgvector` model.

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_search/compare/v0.4.1...HEAD
[0.4.1]: https://github.com/bowerbird-app/RecordingStudio_search/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_search/releases/tag/v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_search/releases/tag/v0.3.0
