# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-09-10

First release of Recording Studio Search (renamed from the gem template).

### Added
- Per-model `searchable` DSL with `:pg_trgm` and `:pgvector` backends
- `Model.search` / `RecordingStudioSearch.search` with blank-query passthrough
- `RecordingStudioSearch.search([ModelA, ModelB], q)` returns a Hash of class => relation (no cross-type ranking)
- `searchable_pg_trgm` and `searchable_pgvector` generators (trigram columns on the model; embeddings in `recording_studio_search_documents`)
- Core query-cache migration without requiring the `vector` extension
- Injectable `embedding_client` and optional `RecordingStudioAI::Embeddings.create!` adapter
- `EmbedDocumentJob`, `embed_later`, digest-skip upserts, and `recording_id` identity for recordables
- Vector → trigram fallback with warnings; no merged result sets
- `recording_studio_search:backfill` and `recording_studio_search:reembed`
- Dummy `User` / `Page` / `Note` proof and tests
- Dummy host names Flatpack `rounded` (`FlatPack.configuration.default_theme`) and stamps `html data-theme="rounded"` without copying core `default_layout`
- Dummy home uses `FlatPack::Search::Component` (GET `q`) instead of a labeled text input plus Search button
- Dummy Flatpack pin is `v0.1.177` so Search idle fill matches the live demo (`--surface-background-color`, not muted grey)
- Dummy GitHub pins: Recording Studio `v4.2.1`, Accessible `v0.9.1`, Root Switchable `v0.5.1`
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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_search/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_search/releases/tag/v0.3.0
