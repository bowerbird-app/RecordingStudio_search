# Recording Studio 6.x Template Update

Copied addons now start on Recording Studio 6.x and still resolve 4.x / 5.x.

- Gemspec: `add_dependency "recording_studio", ">= 4.2", "< 7"`
- Dummy GitHub tags: Recording Studio `v6.3.0`, Accessible `v0.24.0`, Root Switchable `v0.11.0`, Users `v0.26.3`, Admin `v2.7.2`, Attachable `v0.22.0`, Logs `v0.7.1`, Metrics `v0.7.0`, Trashable `v0.12.0`, Cache `v0.6.0`, FlatPack `v0.1.329`
- Authenticated dummy layout: `recording_studio_layout` plus FlatPack CSS/JS. Views set `content_for :title` / `:subtitle` and `flat_pack_page_nav`.
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
- Optional example mixin: `include RecordingStudio::Capabilities::Example.to(**opts)` wraps `RecordingStudio::Capabilities.include_for`. Installing the gem does not enable it globally.
