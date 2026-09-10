# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.1` in the gemspec; dummy GitHub tag `v4.2.0`)
- Accessible dummy tag `v0.6.0` and Root Switchable dummy tag `v0.5.0`
- FlatPack dummy tag `v0.1.133`
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
