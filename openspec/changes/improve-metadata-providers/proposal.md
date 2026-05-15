## Why

Goodreads is becoming increasingly unreliable as a metadata source due to aggressive bot detection and WAF blocking — even the existing Playwright fallback is fragile. The metadata pipeline needs more robust, freely available alternatives to fill the gaps in series info, genres, ratings, and audiobook-specific data.

## What Changed

- **Promoted Hardcover** to primary metadata provider for series, genres, ratings, and cover images — it is already integrated and provides near-parity with Goodreads
- **Added Audnexus** _(Beta)_ as a new audiobook-specific metadata provider (ASIN-based lookup only, REST API, no key required) covering narrator, publisher, genres, series, and cover art
- **Demoted Goodreads** to best-effort / last-resort in the provider chain; WAF blocks treated as soft misses
- **Removed BookBrainz** — the API was found to be alpha-quality during implementation (incorrect documented endpoints, sparse data, multi-round-trip lookups for series). Removed entirely rather than shipping broken integration.
- Keep Open Library and Google Books in their current roles
- **Added ASIN field** to book overview, edit metadata, and search metadata UI

## Capabilities

### New Capabilities

- `audnexus-provider`: Audnexus metadata provider — ASIN-based lookup for audiobook metadata (narrator, series, genres, publisher, cover). Fetches from `audnex.us` REST API with no key required. **Beta:** ASIN-only, no title/author search fallback, coverage limited to Audible titles.

### Modified Capabilities

- `series-enrichment`: Provider priority order changes — Hardcover becomes primary for series/genres; Goodreads becomes optional fallback rather than a required fetch target. (BookBrainz was planned as middle tier but removed.)

### Removed Capabilities

- `bookbrainz-provider`: Removed. The BookBrainz REST API uses incorrect endpoint paths as documented, returns alpha-quality data, and requires multiple round-trips for series data. Not worth the complexity.

## Impact

- `apps/api/src/metadata/` — new Audnexus provider service, provider chain updated, BookBrainz removed
- `apps/api/src/metadata/goodreads.service.ts` — lower priority, WAF failure treated as soft miss
- `apps/api/src/metadata/hardcover.service.ts` — higher priority, expanded field mapping
- `apps/api/src/series/series.service.ts` — series enrichment chain updated to Hardcover → Goodreads
- `apps/web/` — ASIN field added to overview and edit tabs; Audnexus UX improvements in search metadata (ASIN-only warning, not-found toast, hidden when no ASIN)
- No database schema changes required
- No new required environment variables (Audnexus is keyless; `AUDNEXUS_BASE_URL` is optional override)
