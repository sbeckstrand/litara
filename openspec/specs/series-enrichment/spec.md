### Requirement: Enrich endpoint triggers series slot population

The system SHALL provide a `POST /api/v1/series/:id/enrich` endpoint that queries an external metadata provider for the full roster of books in the named series, creates or updates `SeriesSlot` records for books not already in the library, and refreshes `Series.totalBooks` from the provider's current count. The endpoint SHALL be protected by `JwtAuthGuard`. On success it SHALL return 200 with a JSON body containing `{ slotsCreated: number, slotsUpdated: number, totalBooks: number | null }`. On provider failure it SHALL return 502 with a descriptive error message.

#### Scenario: Enrichment creates slots for missing books

- **WHEN** an authenticated user sends `POST /api/v1/series/:id/enrich` and the provider returns a series roster with books at positions not already owned
- **THEN** `SeriesSlot` records are created for each missing position, `Series.totalBooks` is updated to the provider's count, and the response includes the counts of created and updated slots

#### Scenario: Enrichment skips positions already owned

- **WHEN** the provider returns a book at sequence position N and a `SeriesBook` record already exists for that series at sequence N
- **THEN** no `SeriesSlot` is created or updated for that position

#### Scenario: Re-running enrichment updates existing slots

- **WHEN** enrichment is triggered for a series that already has `SeriesSlot` records
- **THEN** existing slots are upserted (title, authors, cover refreshed) and the response `slotsUpdated` count reflects the number refreshed

#### Scenario: Returns 404 for unknown series id

- **WHEN** an authenticated user sends `POST /api/v1/series/:id/enrich` with an id that does not match any series
- **THEN** the response is 404 Not Found

#### Scenario: Returns 502 when provider query fails

- **WHEN** the metadata provider returns an error or is unreachable
- **THEN** the response is 502 with an error message; no partial slot data is written

---

### Requirement: Hardcover is used as the primary enrichment provider when configured

The system SHALL query Hardcover first when `HARDCOVER_API_KEY` is set. The query SHALL search for a series by exact name match (`_eq`) against `Series.name`. If no result is returned, the system SHALL retry with a case-insensitive partial match (`_ilike`). The query SHALL retrieve each `book_series` entry's `position`, the book's `title`, `image { url }`, and `contributions { author { name } }`. The `books_count` field SHALL be used to update `Series.totalBooks`.

#### Scenario: Hardcover enrichment returns full series roster

- **WHEN** `HARDCOVER_API_KEY` is set and Hardcover returns series data for the given name
- **THEN** slots are created for unowned books using Hardcover data and `provider` is set to `"hardcover"`

#### Scenario: Hardcover falls back to ilike when exact match returns empty

- **WHEN** the exact-match query returns no series but an ilike query returns one
- **THEN** the ilike result is used for enrichment

#### Scenario: System falls back to Goodreads when Hardcover is not configured

- **WHEN** `HARDCOVER_API_KEY` is not set
- **THEN** the Goodreads scrape path is used instead

---

### Requirement: Goodreads is used as the fallback enrichment provider

When `HARDCOVER_API_KEY` is not set, the system SHALL attempt to enrich via Goodreads. The system SHALL find any `Book` in the series that has a `goodreadsId`, fetch that book's Goodreads page, extract the series page link, then scrape the series page to obtain the ordered list of books (title, sequence, author, cover image URL). If no book in the series has a `goodreadsId`, enrichment SHALL fail with a 502 and a message indicating no provider is available.

#### Scenario: Goodreads enrichment succeeds from an existing goodreadsId

- **WHEN** Hardcover is not configured and at least one book in the series has `goodreadsId` set
- **THEN** the Goodreads series page is scraped, slots are created for unowned books, and `provider` is set to `"goodreads"`

#### Scenario: Enrichment fails when no goodreadsId exists and Hardcover is unconfigured

- **WHEN** Hardcover is not configured and no book in the series has a `goodreadsId`
- **THEN** the response is 502 with a message indicating no metadata provider is available for this series

---

### Requirement: Cover images for slots are downloaded and stored locally during enrichment

For each slot created or updated during enrichment, the system SHALL attempt to download the cover image from the provider-supplied URL and store it as bytes in `SeriesSlot.coverData`. A cover download failure SHALL be non-fatal — the slot is saved with `coverData: null` and enrichment continues.

#### Scenario: Cover image is stored when provider URL is available

- **WHEN** a slot is created and the provider returns a cover image URL
- **THEN** the image is downloaded and stored in `SeriesSlot.coverData`

#### Scenario: Slot is created without cover when download fails

- **WHEN** the cover image URL is unavailable or the download request fails
- **THEN** the slot is created with `coverData: null` and no error is thrown

---

### Requirement: Admin bulk enrich endpoint triggers series enrichment as a background task

The system SHALL provide a `POST /api/v1/admin/series/enrich-all` endpoint, protected by `JwtAuthGuard` and `AdminGuard`, that creates a `Task` record with `type: "SERIES_BULK_ENRICH"` and `status: "PENDING"`, immediately returns `{ taskId: string }` with HTTP 202, then runs enrichment for every `Series` in the library sequentially in the background. The task payload SHALL be updated after each series is processed to reflect progress (total series count, number completed, number failed). On completion the task status SHALL be set to `"COMPLETED"`. If the background process throws an unhandled error, the task status SHALL be set to `"FAILED"` with an `errorMessage`.

#### Scenario: Endpoint returns taskId immediately

- **WHEN** an admin user sends `POST /api/v1/admin/series/enrich-all`
- **THEN** the response is 202 with `{ taskId: string }` and the task begins running in the background

#### Scenario: Task payload reflects per-series progress

- **WHEN** the bulk enrich task is running and has processed some series
- **THEN** `GET /api/v1/admin/tasks` returns the task with a payload showing `{ total, completed, failed, currentSeries }` updated after each series

#### Scenario: Task reaches COMPLETED when all series are processed

- **WHEN** the background process finishes enriching all series (including those that returned no results or had provider errors)
- **THEN** the task status is set to `"COMPLETED"` with a final payload summary

#### Scenario: Individual series failures do not abort the bulk task

- **WHEN** one series fails enrichment (e.g., provider returns no results)
- **THEN** the failure is counted in `failed`, the task continues to the next series, and the overall task still reaches `"COMPLETED"`

#### Scenario: Non-admin users cannot trigger bulk enrich

- **WHEN** a non-admin authenticated user sends `POST /api/v1/admin/series/enrich-all`
- **THEN** the response is 403 Forbidden

---

### Requirement: Admin Settings page provides a bulk series enrichment button

The Admin Settings page SHALL include an "Enrich All Series" button in a series-related section. Clicking the button SHALL call `POST /api/v1/admin/series/enrich-all`, display a loading state during the HTTP request (not during the full background task), and on success show a notification informing the user that enrichment is running and can be tracked in the Tasks section.

#### Scenario: Clicking "Enrich All Series" starts the task and shows a notification

- **WHEN** an admin user clicks "Enrich All Series" on the Admin Settings page
- **THEN** the button shows a loading state, the bulk enrich endpoint is called, and on success a notification appears telling the user to check the Tasks section for progress

#### Scenario: Button returns to idle state after the request completes

- **WHEN** the `POST /api/v1/admin/series/enrich-all` request resolves (success or error)
- **THEN** the button loading state is cleared regardless of outcome
