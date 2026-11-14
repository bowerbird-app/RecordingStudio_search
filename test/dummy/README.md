# Dummy App

This Rails app exists to validate the Recording Studio search addon in a real host application.

## What It Covers

- Devise actor plus Recording Studio Users `v0.29.0` auth (email, then password)
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables, owner-bootstrapped through Accessible
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

Dummy credentials (`config/credentials.yml.enc`) use the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or write that key to `config/master.key` (gitignored). Do not mint a per-repo dummy key.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password123!`

## Useful Routes

- `/` - mixed search demo (`User` trigram with `unscoped: true`, `Page` vector scoped to the current root, `Note` trigram with `unscoped: true`)
- `/people` - one-model demo: `User.search` only (linked from home as Just people)
- `/instant` - pages you can view, as you type (Turbo Frame + debounce). Dummy allowlists `Page`; hits need Accessible `:view`.
- `/groups` - search people already in a mailbox (`User.where(...).search`)
- `/title-first` - title weight `A` ranks above body weight `D` (try **widgets**)
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Recording Studio Users sign-in (email, then password)
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy-only starter pages
- `/up` - Rails health check

## Why This App Exists

Use this app to verify search generators, embeddings, and fallback before a host enables models. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Authenticated pages call `recording_studio_layout` and render Recording Studio’s default layout (`html data-theme="rounded"`). Dummy keeps a host copy of `recording_studio/shared/_default_layout` aligned with core 6.3 (`content_for :title` / `:subtitle`, `flat_pack_page_nav`, `page_nav_button_group`). Dummy also overrides the root-switch show view so it matches Root Switchable `v0.15.0` (Card uses `border:` / `shadow:`, not `style:`). Sign-in uses Default Layout plus the Users auth shell (`Welcome back`, Continue with email). Dummy names the theme in `config/initializers/flat_pack.rb` (`FlatPack.configuration.default_theme = :rounded`).

The home page in `app/views/home/index.html.erb` searches people and notes with `unscoped: true` and pages with the signed-in actor and `current_root_recording`. The control is a full-width `FlatPack::Search::Component` (`max_width: :none`) submitting GET `q`. `/people` is the same Search control calling `User.search(..., unscoped: true)` only. `/instant` copies `instant_search_field` plus `instant_search_results` against engine `InstantSearchesController#show` for pages the signed-in person can view in the current root. `/groups` keeps a mailbox scope and passes `unscoped: true`. `/title-first` shows weighted ranking inside the same access scope. Deeper explanations live in the product README.
