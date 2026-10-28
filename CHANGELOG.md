# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.1] - 2026-10-28

### Changed

- Stop tracking SimpleCov HTML under `coverage/` and `test/dummy/coverage/`
- Dummy / root pin for Recording Studio Trashable: `v0.10.0` → `v0.11.0`
- Bundler Audit lockfile bumps: `crass` `>= 1.0.8`, `net-ssh` `>= 7.3.5`

### Upgrade notes

- No migration or host code change is required.

## [0.7.0] - 2026-10-14

### Added

- Instant-search chrome looks up `recording_studio.search.*` through
  `RecordingStudio.t` so a missing active locale falls back to English
- Engine registers this gem's `config/locales/en.yml` with
  `RecordingStudio::Translation.register_shipped_english` at boot so the
  final shipped-English table includes search keys when loaded `:en` is pruned

### Changed

- Requires `recording_studio ~> 4.7` (dummy / root pins `v4.7.0`)
- Removed hand-copied English `default:` on shipped search keys looked up
  through `RecordingStudio.t`; optional collection section titles stay on
  view `t` / `I18n.t` with main's `default:` the raw model-derived label
  (host-only keys, not shipped in this gem's `en.yml`)

### Upgrade notes

- Pin hosts to Recording Studio `~> 4.7`.
- Fallback comes from the loaded English, host overrides included.
- A plain default with no interpolation is returned as a plain
  (non-html_safe) String, so views will escape it.
- On a missing `_html` key (verified vs view `t` / `I18n.t` on recording_studio
  v4.7.0): a plain String caller `default:` matches view `t` / `I18n.t` and
  stays unsafe; an Array caller `default:` returns the same string as view `t`
  / `I18n.t` but `RecordingStudio.t` marks it html_safe while view `t` /
  `I18n.t` leave it unsafe.
- Use `RecordingStudio.t` only for this gem's shipped
  `recording_studio.search.*` keys. Host or other-namespace lookups stay on
  `I18n.t` / view `t` with main's `default:`.
- No migration or host code change is required for English output.
- `en.yml` is unchanged. Prefer `RecordingStudio.t` for shipped search keys
  when adding new instant-search copy.

## [0.6.0] - 2026-10-12

### Added

- English `default:` on every instant-search `t(...)` lookup so a host locale
  without a fallback never shows "translation missing"
- Render-time translation for multi-model collection section titles via
  `instant_search_translated_collection_label` (`recording_studio.search.results.collections.<label>`,
  `default:` the raw English from `instant_search_collection_label`)
- Always-loaded dummy host override
  `test/dummy/config/locales/recording_studio_search_host.en.yml` on the rarely
  shown `results.missing_detail` key
- Locale regression: every `lib/**/*.rb` file must not mention
  `i18n.load_path` / `I18n.load_path` (widened from `engine.rb` only)

### Changed

- Instant-search view and helper chrome resolve through `t(..., default: <main English>)`
  (English output unchanged)
- Stricter dummy render-level asserts for column titles `Name` / `Detail` on
  the instant search hits frame (existing `assert_match` kept)
- Dummy boot-order host override test hits a test-only probe page that renders
  `_results` with a no-email/no-body row and asserts `HOST missing mark` in a `td`

### Upgrade notes

- No migration or host code change is required for English.
- To translate or override the defaults, add keys under `recording_studio.search`
  in the host's locale files (including optional
  `results.collections.<demodulized_plural>` for multi-model section titles).
- `instant_search_collection_label` still returns raw English model-derived
  labels (public data). Translate at the render site (the gem partial already
  does via `instant_search_translated_collection_label`).
- There is no dependency on `recording_studio_internationalization`.

## [0.5.0] - 2026-10-09

### Added

- English Rails I18n keys for static interface copy in the gem's own instant-search
  views and helpers (`config/locales/en.yml` under `recording_studio.search`)

### Changed

- Instant-search empty states, table column titles, default search placeholder, and
  missing-detail placeholder resolve through `t(...)` (English output unchanged)
- Dummy / root GitHub pin for Recording Studio: `v4.2.1` → `v4.2.2`
- Dummy `brakeman` `8.0.6` → `8.1.0` so Security CI does not fail on the outdated-version check

### Upgrade notes

- No migration or host code change is required for English.
- To translate or override the defaults, add keys under `recording_studio.search`
  in the host's locale files.
- There is no dependency on `recording_studio_internationalization`.
- This gem had no older top-level `recording_studio_search.*` I18n namespace for
  interface copy; new keys use only `recording_studio.search.*`.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_search/compare/v0.7.1...HEAD
[0.7.1]: https://github.com/bowerbird-app/RecordingStudio_search/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_search/compare/v0.6.1...v0.7.0
[0.6.0]: https://github.com/bowerbird-app/RecordingStudio_search/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_search/releases/tag/v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_search/releases/tag/v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_search/releases/tag/v0.3.0
