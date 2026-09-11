RecordingStudioSearch install complete.

Next steps:

1. Review config/initializers/recording_studio_search.rb.
2. Apply core migrations with `bin/rails db:migrate`.
3. Enable search on each model:
   `bin/rails g recording_studio_search:searchable_pg_trgm User --against=name,email`
   `bin/rails g recording_studio_search:searchable_pgvector SupportPage --against=title:A,body:D`
4. Declare matching `searchable backend: ...` on those models.
5. For :pgvector, set `config.embedding_client` or use RecordingStudioAI embeddings. Secrets stay in the host / AI gem.
