# HypeTV catalogue API contract

The Android TV app never receives or stores an Xtream username or password.
It authenticates with the device token returned by `POST /api/activate` and
requests a customer-specific, normalised catalogue from the HypeTV backend.

## Home catalogue

`GET /api/catalog/home`

Header: `Authorization: Bearer <device-token>`

```json
{
  "shelves": [
    {
      "id": "live-tv",
      "title": "Live TV",
      "items": [
        {
          "id": "channel-123",
          "playback_id": "opaque-reference",
          "type": "live",
          "title": "Hype Sports",
          "subtitle": "Live",
          "image_url": "https://example.com/logo.png",
          "badge": "LIVE",
          "progress": null
        }
      ]
    }
  ]
}
```

Supported item types are `live`, `movie`, `series`, and `episode`.
`playback_id` is an opaque backend reference; it must not contain provider
credentials. Empty shelves are omitted. The preferred order is Continue
Watching, Live TV, Trending Movies, Latest Series, Recently Added, HypeTV
Originals, Sports Tonight, and News.

Until this endpoint is available, the app safely displays its bundled preview
catalogue. As soon as the endpoint returns valid shelves for an activated
device, the app replaces the previews automatically.

## Future endpoints

- `GET /api/catalog/live`
- `GET /api/catalog/movies`
- `GET /api/catalog/series`
- `GET /api/catalog/search?q=<query>`
- `GET /api/playback/{playback_id}` for a short-lived playback session
- `GET /api/favourites`
- `PUT /api/favourites/{content_id}`
- `DELETE /api/favourites/{content_id}`

The backend is responsible for validating the customer subscription and
connection allowance before returning catalogue or playback data.
