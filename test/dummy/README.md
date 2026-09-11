# Dummy App

This Rails app exists to validate the Recording Studio search addon in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- Trigram search on `User` and `Note`
- Vector search on `Page` with trigram fallback
- Recording Studio default layout with Flatpack `rounded` on `html` and `body` (no vendored layout copy)
- FlatPack assets and Tailwind source scanning
- Mounted `RecordingStudio::Engine` route behavior inside a host app
- Dummy-only `/docs/*` pages for gem-specific onboarding

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

- `/` - search demo (`User` trigram, `Page` vector, `Note` trigram) via `RecordingStudioSearch.search([User, Page, Note], q)`
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy-only starter pages
- `/up` - Rails health check

## Why This App Exists

Use this app to verify search generators, embeddings, and fallback before a host enables models. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Authenticated pages include `RecordingStudio::UsesDefaultLayout` and render the gem's `recording_studio/default_layout` (theme `rounded` on `body`; dummy also stamps `data-theme="rounded"` on `html`). Devise sign-in keeps `layouts/application`, which already sets `html data-theme="rounded"`. Dummy names the theme in `config/initializers/flat_pack.rb` (`FlatPack.configuration.default_theme = :rounded`).

The home page in `app/views/home/index.html.erb` is a minimal demo of `RecordingStudioSearch.search([User, Page, Note], q)`. Deeper explanations live in the product README.
