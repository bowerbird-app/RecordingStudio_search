# Dummy demos

`instant-search-demo.mp4` is `/instant` in the dummy app: type Ada, the Turbo Frame fills, the URL stays `/instant`. That page searches `User` with trigram. Instant search itself can target a `:pgvector` model the same way.

If a binary fetch corrupts the mp4, decode the text sibling:

```bash
base64 -d docs/demo/instant-search-demo.mp4.b64 > instant-search-demo.mp4
```

`instant-search-demo.mp4.b64.manifest` has `sha256` and `original_bytes`.

`instant-ada.png` is the same `/instant` page after typing Ada (Ada Admin, Ada Lovelace). Decode `instant-ada.png.b64` the same way if the binary fetch is unusable.
