## Context

The metadata pipeline previously had four providers: Google Books, Open Library, Goodreads, and Hardcover. Goodreads is increasingly unreliable due to aggressive WAF bot detection. The `DEFAULT_FIELD_CONFIG` in `metadata.service.ts` assigns Hardcover as the primary provider for `genres` and series fields, with Goodreads as a best-effort fallback.

One new keyless provider was added:

- **Audnexus** (`audnex.us`) — REST API purpose-built for audiobook metadata; returns narrator, series, publisher, genres, and cover art via ASIN. **No title/author search fallback** — ASIN is required.

BookBrainz was evaluated and removed. See `specs/bookbrainz-provider/spec.md`.

The existing `PlaywrightService` Goodreads fallback was removed (`playwright.service.ts` deleted). Goodreads requests now use direct HTTP fetch; WAF blocks are soft misses.

## Goals / Non-Goals

**Goals:**

- Add `AudnexusService` provider for audiobook metadata (ASIN-only lookup)
- Promote Hardcover as the primary provider for `genres` and series fields
- Demote Goodreads — treat WAF blocks as soft misses, not errors, so the pipeline continues
- Add ASIN field to book overview, edit metadata, and search metadata UI
- No new required environment variables

**Non-Goals:**

- Replacing or removing Goodreads entirely — keep it as an optional enrichment source
- Audiobook detection logic beyond checking for an ASIN on the book record
- Paid provider integrations
- Mobile app changes

## Decisions

### 1. Audnexus endpoint strategy

**Decision:** Use ASIN as the only lookup key (`GET /books/:asin`). No title/author fallback is implemented.

**Why:** Audnexus has no title/author search endpoint. ASIN-native lookups are the only supported query type. When a book has no ASIN the service returns `null` immediately with a debug log. The Search Metadata UI hides the Audnexus option when the book record has no ASIN.

### 2. BookBrainz — removed

**Decision:** Not integrated. Removed after API evaluation.

**Why:** The documented endpoints (`/search/work`, `/ws/2`) don't match the actual REST API. Data quality is alpha-level and sparse. Retrieving series data requires multiple round-trips. Not worth shipping broken integration.

### 3. Genres field ownership

**Decision:** Change `DEFAULT_FIELD_CONFIG` `genres` assignment from `goodreads` to `hardcover`. Add Goodreads as a disabled-by-default secondary. Add Audnexus as a disabled-by-default secondary.

**Why:** Hardcover has crowd-sourced genre data comparable to Goodreads shelves and is more reliably reachable. Goodreads genres remain available as an opt-in fallback. Audnexus genres are available for audiobook-heavy libraries via opt-in.

### 4. Goodreads failure handling

**Decision:** In `GoodreadsService`, catch WAF-blocked responses (HTTP 403 / `GOODREADS_WAF_BLOCKED`) and return `null` instead of throwing. The metadata orchestration layer already skips null provider results.

**Why:** Currently a Goodreads WAF block surfaces as an error that can abort enrichment. Treating it as a soft miss lets the chain continue to the next provider without any code changes in `metadata.service.ts`.

### 5. Provider registration

**Decision:** Register `AudnexusService` in `MetadataModule` alongside existing providers. Add it to `PROVIDERS_CONFIG` with `requiresApiKey: false`, `envKey: null`, and `label: 'Audnexus (Beta)'`.

**Why:** Consistent with the existing pattern. Keyless providers are always available and need no conditional registration logic. Beta label signals community-hosted dependency and ASIN-only coverage limitation.

### 6. ASIN field

**Decision:** Add `asin` to the book record's overview, edit metadata tab, and search metadata apply flow. Audnexus is hidden from the Search Metadata provider list when the book has no ASIN.

**Why:** ASIN is required for Audnexus lookups and is useful metadata on its own (links to Audible). Hiding Audnexus when there's no ASIN prevents user confusion from a provider that silently returns nothing.

### 7. Series enrichment chain

**Decision:** Hardcover → Goodreads. BookBrainz tier removed.

**Why:** BookBrainz removed (see decision 2). Two-provider chain is simpler and covers the vast majority of series lookup cases.

## Risks / Trade-offs

- **[Audnexus coverage]** Audnexus only covers Audible-released audiobooks — standard ebooks without ASINs get no benefit. This is inherent to the provider; no workaround.
- **[Audnexus availability]** `audnex.us` is community-hosted with no SLA. An outage returns null (soft miss); the pipeline continues with other providers.
- **[Goodreads reliability]** WAF blocks are now soft misses instead of errors, so the pipeline degrades gracefully, but Goodreads data may become unavailable at any time.

## Migration Plan

1. Add `AudnexusService` under `apps/api/src/metadata/providers/`.
2. Register it in `MetadataModule`.
3. Update `DEFAULT_FIELD_CONFIG` to reassign `genres` to `hardcover`, add disabled-by-default `audnexus` entries for `description` and `genres`.
4. Update `MetadataProvider` enum and `PROVIDERS_CONFIG`.
5. Fix Goodreads WAF error handling to return `null` instead of throwing.
6. Update series enrichment provider chain to Hardcover → Goodreads.
7. Add `asin` field to frontend book overview, edit metadata tab, and search metadata apply flow.
8. Filter Audnexus from Search Metadata provider list when book has no ASIN; show info note when selected.

No database migrations required. `AUDNEXUS_BASE_URL` is an optional env var override for self-hosted Audnexus instances. Rollback: revert `DEFAULT_FIELD_CONFIG` and remove `audnexus.service.ts`.
