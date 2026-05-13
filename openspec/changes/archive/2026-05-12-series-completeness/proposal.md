## Why

The Series Detail page only shows books the user already owns, so there is no way to see what they're missing from a series. When a series has 7 books and the user owns 3, the other 4 are invisible — making it impossible to plan future acquisitions or understand how complete their collection is.

## What Changes

- **New `SeriesSlot` database table** stores metadata for series books not in the library (title, sequence, authors, locally-stored cover image, provider attribution).
- **New `POST /api/v1/series/:id/enrich` endpoint** queries Hardcover (if `HARDCOVER_API_KEY` is set) or Goodreads (fallback) for the full series roster, creates `SeriesSlot` records for missing books, and refreshes `Series.totalBooks` from the provider's current count.
- **New `GET /api/v1/series/slots/:id/cover` endpoint** serves the locally-stored cover image for a slot.
- **Series Detail page** gains a "Fetch Complete Series" button (always visible) and displays unowned books as greyed-out ghost cards interleaved with owned books by sequence order. Clicking a ghost card opens a popover showing title, authors, and a "Copy title & author" button.
- **Auto-resolve**: when a book is added to the library and assigned to a series at a position that matches an existing `SeriesSlot`, the slot is deleted automatically.
- **`Series.totalBooks`** is refreshed from the provider on every enrichment fetch, keeping the count current as series grow over time.
- **Admin Settings page** gains an "Enrich All Series" button that creates a background `Task` (type `SERIES_BULK_ENRICH`) and runs enrichment across every series in the library sequentially. Progress is visible in the existing admin task list.

## Capabilities

### New Capabilities

- `series-slot`: The `SeriesSlot` data model, its cover-serve endpoint, and the auto-resolve behavior when an owned book lands on a slot's position.
- `series-enrichment`: The `POST /series/:id/enrich` endpoint, Hardcover series query, Goodreads series scrape fallback, slot upsert logic, `Series.totalBooks` refresh, and the `POST /admin/series/enrich-all` bulk task endpoint with its Admin Settings UI button.

### Modified Capabilities

- `series-browser`: The Series Detail page now includes `slots[]` in the `GET /series/:id` response and renders ghost cards for unowned books alongside owned book cards, plus the "Fetch Complete Series" button.

## Impact

- **Database**: new migration adding `SeriesSlot` model.
- **API**: new `POST /series/:id/enrich` and `GET /series/slots/:id/cover` endpoints; `GET /series/:id` response shape extended with `slots[]`.
- **Metadata providers**: `HardcoverService` gains a series-by-name query method; `GoodreadsService` gains a series-page scrape method.
- **Library write path**: `LibraryWriteService` checks for slot auto-resolve on series assignment.
- **Frontend**: `SeriesDetailPage.tsx` updated with ghost cards, fetch button, and copy popover; `AdminSettingsPage.tsx` gains the "Enrich All Series" button.
- **No breaking changes** to existing endpoints — `slots` is an additive field on the series detail response, and the new admin endpoint is additive.
