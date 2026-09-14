# Dummy App

This Rails app exists to validate the Recording Studio search addon in a real host application.

## What It Covers

- Devise actor plus Recording Studio Users `v0.11.0` auth (email, then password)
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- Trigram search on `User` and `Note`
- Vector search on `Page` with trigram fallback and title `A` / body `D` weights
- Recording Studio default layout with Flatpack `rounded` on `html` and `body` (no vendored layout copy)
- FlatPack assets and Tailwind source scanning
- Mounted `RecordingStudio::Engine` route behavior inside a host app
- Dummy-only `/docs/*` pages for gem-specific onboarding
- `/people` one-model search (`User.search`) alongside mixed home search
- `/instant` Turbo Frame instant search (`recording_studio_search.instant_search_field`)
- `/groups` scoped people search and `/title-first` weighted page ranking

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Useful Routes

- `/` - mixed search demo (`User` trigram, `Page` vector, `Note` trigram) via `RecordingStudioSearch.search([User, Page, Note], q)`
- `/people` - one-model demo: `User.search` only (linked from home as Just people)
- `/instant` - same people search as you type (Turbo Frame + debounce). Dummy allowlists `User` (trigram); a host can allowlist a `:pgvector` model on the same helpers.
- `/groups` - search people already in a mailbox (`User.where(...).search`)
- `/title-first` - title weight `A` ranks above body weight `D` (try **widgets**)
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Recording Studio Users sign-in (email, then password)
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy-only starter pages
- `/up` - Rails health check

## Why This App Exists

Use this app to verify search generators, embeddings, and fallback before a host enables models. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Authenticated pages include `RecordingStudio::UsesDefaultLayout` and render the gem's `recording_studio/default_layout` (theme `rounded` on `body`; dummy also stamps `html data-theme="rounded"`). Sign-in uses the Users gem layout `recording_studio_user/auth` (`Welcome back`, Continue with email). Dummy names the theme in `config/initializers/flat_pack.rb` (`FlatPack.configuration.default_theme = :rounded`).

The home page in `app/views/home/index.html.erb` is a minimal demo of `RecordingStudioSearch.search([User, Page, Note], q)` with a full-width `FlatPack::Search::Component` (`max_width: :none`) submitting GET `q`. `/people` is the same Search control calling `User.search` only. `/instant` copies `instant_search_field` plus `instant_search_results` against engine `InstantSearchesController#show` (type, no full-page reload). `/groups` keeps a mailbox scope. `/title-first` shows weighted ranking. Deeper explanations live in the product README.
