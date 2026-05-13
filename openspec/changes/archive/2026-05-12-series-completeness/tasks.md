## 1. Database

- [x] 1.1 Add `SeriesSlot` model to `apps/api/prisma/schema.prisma` with fields: `id`, `seriesId` (FK → Series, cascade), `title`, `sequence` (Float?), `authors` (String[]), `coverData` (Bytes?), `provider` (String), `externalId` (String?), `createdAt`, `updatedAt`, and `@@unique([seriesId, sequence])`
- [x] 1.2 Add `slots SeriesSlot[]` relation to the `Series` model in schema.prisma
- [x] 1.3 Run `npx prisma migrate dev --name add-series-slot` and verify migration applies cleanly

## 2. SeriesSlot Cover Endpoint

- [x] 2.1 Add `GET /series/slots/:id/cover` route to `series.controller.ts` returning `coverData` bytes with appropriate `Content-Type`, 404 if slot not found or coverData null
- [x] 2.2 Add the slot cover lookup method to `series.service.ts`

## 3. Hardcover Series Query

- [x] 3.1 Add `fetchSeriesByName(seriesName: string)` method to `HardcoverService` using the `series(where: { name: { _eq: ... } })` GraphQL query with `books_count` and `book_series { position, book { title, image { url }, contributions { author { name } } } }`
- [x] 3.2 Add ilike fallback in `fetchSeriesByName` when the exact-match query returns no results

## 4. Goodreads Series Scrape

- [x] 4.1 Add `fetchSeriesByGoodreadsId(goodreadsId: string)` method to `GoodreadsService` that fetches the book page, extracts the series page link, then scrapes the series page for ordered book entries (title, position, author, cover URL)

## 5. Series Enrichment Service Logic

- [x] 5.1 Add `enrichSeries(seriesId: string)` method to `series.service.ts` that: looks up the series + its books, selects provider (Hardcover if key present, else Goodreads), calls the appropriate provider method, returns 502-appropriate error if no provider available
- [x] 5.2 In `enrichSeries`: filter provider results to exclude positions already covered by a `SeriesBook` entry; upsert `SeriesSlot` records for remaining positions
- [x] 5.3 In `enrichSeries`: for each slot being created/updated, attempt to download the cover image URL and store bytes in `coverData`; treat download failure as non-fatal (null coverData)
- [x] 5.4 In `enrichSeries`: update `Series.totalBooks` from the provider's `books_count` value after slot upsert completes
- [x] 5.5 Return `{ slotsCreated, slotsUpdated, totalBooks }` from `enrichSeries`

## 6. Enrich Endpoint

- [x] 6.1 Add `POST /series/:id/enrich` route to `series.controller.ts` with `@ApiBearerAuth()`, `@JwtAuthGuard()`, calling `enrichSeries` and returning the result; map provider errors to 502

## 7. Series Detail DTO + Response

- [x] 7.1 Create `SeriesSlotItemDto` with fields: `id`, `title`, `sequence` (number | null), `authors` (string[]), `hasCover` (boolean)
- [x] 7.2 Add `slots: SeriesSlotItemDto[]` to `SeriesDetailDto`
- [x] 7.3 Update `series.service.ts` `findOne` to include `SeriesSlot` records in the query, map them to `SeriesSlotItemDto`, and include them in the returned `SeriesDetailDto`

## 8. Auto-Resolve on Series Assignment

- [x] 8.1 In `library-write.service.ts`, after creating a `SeriesBook` record, check if the book has a non-null `seriesPosition`; if so, delete any `SeriesSlot` with matching `seriesId` and `sequence`

## 9. Frontend — Ghost Cards and Fetch Button

- [x] 9.1 Update `SeriesDetail` interface in `SeriesDetailPage.tsx` to include `slots: SeriesSlotItem[]` with fields `id`, `title`, `sequence`, `authors`, `hasCover`
- [x] 9.2 Add `SlotCard` component to `SeriesDetailPage.tsx`: same dimensions as `BookCard`, reduced opacity + desaturation, "Not in library" badge overlay, cover from `/api/v1/series/slots/:id/cover` when `hasCover`, otherwise placeholder icon
- [x] 9.3 In the book strip, merge `detail.books` and `detail.slots` into a single array sorted by `sequence` (nulls last), rendering `BookCard` for owned entries and `SlotCard` for slots
- [x] 9.4 Add a Mantine `Popover` to `SlotCard` that opens on click, showing title, authors, and a "Copy title & author" button that writes `"<title> by <authors>"` to clipboard then closes the popover
- [x] 9.5 Add "Fetch Complete Series" `Button` to the page header area (near the Back button); on click call `POST /api/v1/series/:id/enrich`, show loading state on the button, on success reload the series detail, on failure show a Mantine notification with the error

## 10. Admin Bulk Enrich

- [x] 10.1 Add `POST /admin/series/enrich-all` route to `admin.controller.ts` with `@ApiBearerAuth()`, `@UseGuards(JwtAuthGuard, AdminGuard)`, `@HttpCode(HttpStatus.ACCEPTED)`, delegating to `AdminService`
- [x] 10.2 Add `bulkEnrichSeries()` method to `admin.service.ts`: create a `Task` record with `type: 'SERIES_BULK_ENRICH'`, `status: 'PENDING'`, fire-and-forget `runBulkEnrichSeries(taskId)`, return `{ taskId }`
- [x] 10.3 Implement `runBulkEnrichSeries(taskId)` in `admin.service.ts`: set task to `PROCESSING`, fetch all series IDs, iterate sequentially calling `seriesService.enrichSeries(id)` for each, update payload after each with `{ total, completed, failed, currentSeries }`, set `COMPLETED` or `FAILED` when done — individual series errors increment `failed` and continue
- [x] 10.4 Inject `SeriesService` into `AdminModule` (or call enrichment logic via a shared path) so `AdminService` can invoke `enrichSeries`
- [x] 10.5 Add "Enrich All Series" button to `AdminSettingsPage.tsx` in an appropriate section (e.g. near metadata provider settings); on click call `POST /api/v1/admin/series/enrich-all`, show button loading state during the request, on success show a Mantine notification directing the user to the Tasks section

## 11. Verification

- [x] 11.1 Run `cd apps/api && npm run build` and confirm no TypeScript errors
- [x] 11.2 Manually test: add a series book, trigger per-series enrich, verify slots appear as ghost cards in the strip interleaved with owned cards
- [x] 11.3 Manually test auto-resolve: scan/add a book whose series position matches an existing slot, verify the ghost card disappears
- [x] 11.4 Manually test copy popover: click a ghost card, click "Copy title & author", confirm clipboard content
- [x] 11.5 Manually test bulk enrich: click "Enrich All Series" in admin settings, confirm task appears in Tasks section with correct progress payload, reaches COMPLETED
