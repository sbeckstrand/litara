## Context

The library currently models series membership via a `SeriesBook` join table that links `Series` ↔ `Book`. Every entry in `SeriesBook` refers to a real `Book` record in the user's library. `Series.totalBooks` captures the expected total (populated from metadata enrichment) but the books filling those positions are unknown until the user actually owns them.

The metadata providers already return series info at the individual-book level (`seriesName`, `seriesPosition`, `seriesTotalBooks`) but no current code queries a provider for the full roster of a series. Both Hardcover and Goodreads can supply this.

## Goals / Non-Goals

**Goals:**

- Store lightweight records for series books the user does not own (title, sequence, authors, cover).
- Fetch those records on-demand via a user-triggered button, using Hardcover or Goodreads.
- Render unowned books as ghost cards in the Series Detail page, interleaved with owned books by sequence.
- Auto-delete a slot when the user adds a book that lands on that slot's sequence position.
- Keep `Series.totalBooks` accurate by refreshing it from the provider on every enrichment fetch.

**Non-Goals:**

- Background/automatic enrichment (no scheduler, no queue — user triggers explicitly).
- Showing ghost cards in the "In This Series" section on the Book Detail overview tab (out of scope for this change).
- Acquisition workflow beyond copying title + author to the clipboard.
- Multi-provider merge (one provider per enrichment run, not blended).

## Decisions

### 1. Separate `SeriesSlot` table (not phantom `Book` records, not JSON)

**Decision:** New `SeriesSlot` model, isolated from the `Book` table.

**Why:** Phantom `Book` records would require every existing query to filter `inLibrary = true`, risking regressions across search, shelves, smart shelves, OPDS, and reading progress. A JSON blob on `Series` is unqueryable and harder to update incrementally. `SeriesSlot` is self-contained — existing code is untouched.

**Alternative considered:** `Book { inLibrary: Boolean }` — rejected due to widespread query-pollution risk.

### 2. Manual "Fetch Complete Series" trigger

**Decision:** User clicks a button; no background scheduler.

**Why:** Provider APIs have rate limits (Hardcover: 60 req/min). An automatic trigger on every series view or on book add would silently burn quota. A manual trigger gives the user control and makes API usage predictable. The button is always shown (not gated on `totalBooks`) so the user can refresh even when the series has grown beyond what was last stored.

### 3. Provider priority: Hardcover → Goodreads

**Decision:** If `HARDCOVER_API_KEY` is configured, use Hardcover. Otherwise fall back to Goodreads scraping.

**Why:** Hardcover is a structured GraphQL API — reliable field names, proper pagination, no DOM parsing. Goodreads is a scrape and subject to markup changes; it is the fallback only because many users will not have a Hardcover key. Both paths produce the same output shape (title, sequence, authors, cover URL).

**Hardcover query shape:**

```graphql
query GetSeriesByName($name: String!) {
  series(where: { name: { _eq: $name } }, limit: 1) {
    id
    name
    books_count
    book_series(order_by: { position: asc }) {
      position
      book {
        title
        image {
          url
        }
        contributions {
          author {
            name
          }
        }
      }
    }
  }
}
```

**Goodreads fallback:**

1. Find any `Book` in the series that has `goodreadsId` set.
2. `GET https://www.goodreads.com/book/show/<goodreadsId>` — extract the series link from the page.
3. `GET` the series page — scrape the ordered book list (title, position, cover image URL, author).

### 4. Cover images stored locally as `Bytes`

**Decision:** Download provider cover URLs at enrichment time and store in `SeriesSlot.coverData`.

**Why:** Consistent with how `Book.coverData` works. Avoids hotlinking to provider CDNs (which may rate-limit or rotate URLs). The Series Detail page uses a single local endpoint pattern for all cover images.

**Trade-off:** Adds Bytes storage per slot. Acceptable — series rarely exceed ~20 books and covers are small JPEGs (typically 20–80 KB each).

### 5. Auto-resolve by `(seriesId, sequence)` match

**Decision:** When `LibraryWriteService` assigns a book to a series and the book has a `seriesPosition`, delete any `SeriesSlot` with matching `(seriesId, sequence)`.

**Why:** The `@@unique([seriesId, sequence])` constraint means at most one slot occupies a given position. Matching on position is simpler and more reliable than matching on title (which may differ between editions or contain subtitle variations).

**Edge case:** A book without a `seriesPosition` (null) never auto-resolves a slot, because we cannot safely match on `null`. The user can manually re-fetch to clear stale slots.

## Risks / Trade-offs

- **Series name mismatch** → Hardcover stores series names exactly (e.g. "The Stormlight Archive"). If the name on our `Series` record differs even slightly, the GraphQL `_eq` filter returns zero results. Mitigation: fall back to `_ilike` with a trimmed name if `_eq` returns empty.
- **Goodreads markup changes** → scraping is fragile. Mitigation: the Goodreads path is a fallback; errors surface as a user-visible "enrichment failed" message rather than a silent no-op.
- **Slot/book sequence collisions** → if provider data assigns a position that already exists in `SeriesBook`, the upsert skips that position (owned book takes precedence).
- **Cover download failures** → non-fatal; slot is created with `coverData: null` and falls back to the generic placeholder in the UI.
- **Re-fetch overwrites manual edits** → there are no manual edits to slots (they are read-only, provider-sourced). Re-fetch is always a full upsert, safe to repeat.

## Migration Plan

1. Add `SeriesSlot` model to `prisma/schema.prisma`.
2. `npx prisma migrate dev --name add-series-slot` generates and applies the migration.
3. Deploy API — existing series data is unaffected; slot table starts empty.
4. No rollback complexity: dropping the table restores prior state with no data loss to `Book` or `Series`.
