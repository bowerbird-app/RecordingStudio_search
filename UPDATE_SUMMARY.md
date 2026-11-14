# Recording Studio 6.x Template Update

Copied addons now start on Recording Studio 6.x and still resolve 4.x / 5.x.

- Gemspec: `add_dependency "recording_studio", ">= 4.2", "< 7"`
- Dummy GitHub tags: Recording Studio `v6.14.0`, Accessible `v0.41.0`, Root Switchable `v0.15.0`, Users `v0.29.0`, Admin `v2.13.1`, Attachable `v0.26.0`, Logs `v0.7.5`, Metrics `v0.8.0`, Trashable `v0.15.0`, Cache `v0.6.3`, FlatPack `v0.1.374`
- Authenticated dummy layout: `recording_studio_layout` plus FlatPack CSS/JS. Views set `content_for :title` / `:subtitle` and `flat_pack_page_nav`.
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
- Search does not ship the template `Capabilities::Example` mixin.
