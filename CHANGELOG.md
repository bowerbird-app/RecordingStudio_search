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

### Upgrade notes
- This is the first search release. Copy the initializer, run `recording_studio_search:install`, then enable each model with the searchable generators. Do not add embedding columns to host tables.
- Set `config.embedding_client` or wait for `RecordingStudioAI::Embeddings.create!`. Missing embeddings make `:pgvector` models search as trigram until fixed.
- Freeze `embedding_dimensions` before the first pgvector migration. To change dimensions, migrate the documents column yourself and run `recording_studio_search:reembed`.

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_search/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_search/releases/tag/v0.3.0
