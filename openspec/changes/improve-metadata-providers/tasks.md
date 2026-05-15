## 1. Goodreads WAF Soft-Miss Fix

- [x] 1.1 In `goodreads.service.ts`, catch WAF-blocked responses (HTTP 403 / `GOODREADS_WAF_BLOCKED`) and return `null` instead of throwing an error
- [x] 1.2 Verify that `metadata.service.ts` skips `null` provider results and does not surface them as errors (no change needed if already handled, otherwise fix)

## 2. Hardcover Promotion

- [x] 2.1 In `DEFAULT_FIELD_CONFIG` in `metadata.service.ts`, change the `genres` field assignment from `goodreads` to `hardcover`
- [x] 2.2 Add Goodreads as a secondary fallback for `genres` (used only when Hardcover returns empty genres)

## 3. Audnexus Provider (Beta)

- [x] 3.1 Add `MetadataProvider.Audnexus = 'audnexus'` to the `MetadataProvider` enum in `metadata.service.ts`
- [x] 3.2 Add Audnexus entry to `PROVIDERS_CONFIG` (`requiresApiKey: false`, `envKey: null`, `label: 'Audnexus (Beta)'`)
- [x] 3.3 Create `apps/api/src/metadata/providers/audnexus.service.ts` with ASIN-primary lookup (`GET /books/:asin`). Title+author fallback is not implemented — Audnexus has no title search endpoint; the service returns `null` with a debug log when called without an ASIN.
- [x] 3.4 Map Audnexus response fields to `MetadataResult` (title, authors, description, publisher, seriesName, seriesPosition, genres, coverUrl, asin; narrators stored as `"Narrator: <name>"` in categories)
- [x] 3.5 Register `AudnexusService` in `MetadataModule` (providers array; not exported — used only internally)
- [x] 3.6 Add disabled-by-default `audnexus` entries to `DEFAULT_FIELD_CONFIG` for `description` and `genres`
- [x] 3.7 Add debug logging to `searchByAsin`: log request URL, HTTP status, and mapped result title

## 4. BookBrainz Provider — REMOVED

> BookBrainz was evaluated during implementation and removed. The documented API endpoints (`/search/work`, `/ws/2`) do not match the actual REST API, the data is alpha-quality, and retrieving series data requires multiple round-trips. All tasks 4.x are cancelled.

- [~] 4.1 ~~Add BookBrainz to MetadataProvider enum~~ — removed
- [~] 4.2 ~~Add BookBrainz to PROVIDERS_CONFIG~~ — removed
- [~] 4.3 ~~Create bookbrainz.service.ts~~ — removed
- [~] 4.4 ~~Map BookBrainz series data to MetadataResult~~ — removed
- [~] 4.5 ~~Register BookBrainzService in MetadataModule~~ — removed
- [~] 4.6 ~~Add bookbrainz fallback for seriesName/seriesPosition in DEFAULT_FIELD_CONFIG~~ — removed

## 5. Series Enrichment Provider Chain Update

- [x] 5.1 Update series enrichment fallback order to: Hardcover → Goodreads (BookBrainz tier removed)
- [x] 5.2 Remove `BookBrainzService` import and constructor injection from `SeriesService`
- [x] 5.3 Ensure the Goodreads path is only reached when Hardcover returns no usable data
- [x] 5.4 Update provider chain comment to reflect Hardcover → Goodreads

## 6. ASIN Field

- [x] 6.1 Add `asin` to `BookDetailDto` and `findOne` return in `books.service.ts`
- [x] 6.2 Add `asin?: string | null` to `UpdateBookDto`; handle in `updateBook`
- [x] 6.3 Add `asin` to `BookDetail` interface and `EditedFields` in frontend types
- [x] 6.4 Display ASIN in book Overview tab (`DetailRow`)
- [x] 6.5 Add ASIN `TextInput` to Edit Metadata tab Details grid
- [x] 6.6 Include `asin` in `detailToEdited` mapping and `handleSave` patch payload
- [x] 6.7 Add ASIN row to `buildRows` and apply logic in `buildApplyPayload` in `metadataApply.shared.ts`

## 7. Audnexus Search UX

- [x] 7.1 In `SearchMetadataTab`, filter Audnexus from the provider list when `detail.asin` is falsy
- [x] 7.2 Show an info note below the search bar when Audnexus is selected: "Audnexus searches by ASIN only — title and author are ignored"
- [x] 7.3 Show a yellow toast when Audnexus is searched and returns no results: "Audnexus: no audiobook found for ASIN \<asin\>"
- [x] 7.4 Pass `book.asin` to `searchFromProvider` via `searchExternalMetadata`; Audnexus returns `[]` when no ASIN is available

## 8. Search ISBN Override Fix

- [x] 8.1 Frontend always sends `isbn` query param (even empty string) so clearing the field is respected
- [x] 8.2 Backend `searchExternalMetadata` uses `overrides.isbn || undefined` — drops the `book.isbn13` fallback when the user has explicitly cleared the field

## 9. Verification

- [x] 9.1 Run `npm run build` from the root and confirm zero TypeScript errors
- [ ] 9.2 Manually trigger a book enrichment with a known ASIN to verify Audnexus integration end-to-end
- [x] 9.3 Confirm the admin metadata provider configuration page lists Audnexus (BookBrainz should not appear)
