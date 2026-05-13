### Requirement: SeriesSlot persists metadata for unowned series books

The system SHALL store a `SeriesSlot` record for each book in a series that is not present in the user's library. Each slot SHALL contain: `id` (UUID PK), `seriesId` (FK → `Series`, cascade delete), `title` (String), `sequence` (Float, nullable), `authors` (String array), `coverData` (Bytes, nullable), `provider` (String — `"hardcover"` or `"goodreads"`), `externalId` (String, nullable — provider-specific book identifier), `createdAt`, `updatedAt`. The combination of `(seriesId, sequence)` SHALL be unique, enforced at the database level.

#### Scenario: Slot is created for a missing series position

- **WHEN** the enrichment process identifies a book at sequence position N that has no corresponding `SeriesBook` entry for that series
- **THEN** a `SeriesSlot` is created with the book's title, sequence, authors, and cover data for that series

#### Scenario: Unique constraint prevents duplicate slots per position

- **WHEN** enrichment runs twice for the same series
- **THEN** the second run upserts existing slots rather than creating duplicates, updating title, authors, and cover data in place

#### Scenario: Slot cascade-deletes when its series is deleted

- **WHEN** a `Series` record is deleted
- **THEN** all associated `SeriesSlot` records are automatically deleted

---

### Requirement: SeriesSlot cover image is served via a dedicated endpoint

The system SHALL provide a `GET /api/v1/series/slots/:id/cover` endpoint that returns the `coverData` bytes for a given slot as an image response. The endpoint SHALL return 404 if no slot with that id exists or if `coverData` is null. The endpoint SHALL be protected by `JwtAuthGuard`.

#### Scenario: Cover image is returned for a slot with cover data

- **WHEN** an authenticated user requests `GET /api/v1/series/slots/:id/cover` and the slot has `coverData`
- **THEN** the response is 200 with the image bytes and an appropriate `Content-Type` header

#### Scenario: 404 returned for slot without cover data

- **WHEN** an authenticated user requests `GET /api/v1/series/slots/:id/cover` and the slot exists but `coverData` is null
- **THEN** the response is 404 Not Found

#### Scenario: 404 returned for unknown slot id

- **WHEN** an authenticated user requests `GET /api/v1/series/slots/:id/cover` with an id that does not match any slot
- **THEN** the response is 404 Not Found

---

### Requirement: SeriesSlot is auto-resolved when an owned book matches its position

The system SHALL automatically delete a `SeriesSlot` when a book is assigned to a series and the book's `seriesPosition` matches the `sequence` of an existing slot for that series. The check SHALL occur during the series-assignment step in the library write path, after the `SeriesBook` record is created.

#### Scenario: Slot is deleted when owned book fills its position

- **WHEN** a book with `seriesPosition = 3` is added to a series, and a `SeriesSlot` exists for that series at `sequence = 3`
- **THEN** the `SeriesSlot` at sequence 3 is deleted

#### Scenario: Null seriesPosition does not trigger auto-resolve

- **WHEN** a book with no `seriesPosition` (null) is added to a series
- **THEN** no `SeriesSlot` records are deleted by the auto-resolve logic

#### Scenario: Auto-resolve does not affect slots at other positions

- **WHEN** a book with `seriesPosition = 3` fills its slot
- **THEN** `SeriesSlot` records at other sequence positions for the same series are unaffected
