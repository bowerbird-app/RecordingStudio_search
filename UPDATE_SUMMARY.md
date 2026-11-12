# Recording Studio 6.x Template Update

Copied addons now start on Recording Studio 6.x and still resolve 4.x / 5.x.

- Gemspec: `add_dependency "recording_studio", ">= 4.2", "< 7"`
- Dummy GitHub tags: Recording Studio `v6.5.0`, Accessible `v0.24.2`, Root Switchable `v0.11.4`, Users `v0.27.1`, Admin `v2.8.2`, Attachable `v0.22.0`, Logs `v0.7.4`, Metrics `v0.7.3`, Trashable `v0.12.3`, Cache `v0.6.2`, FlatPack `v0.1.341`
- Authenticated dummy layout: `recording_studio_layout` plus FlatPack CSS/JS. Views set `content_for :title` / `:subtitle` and `flat_pack_page_nav`.
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
- Search does not ship the template `Capabilities::Example` mixin.
