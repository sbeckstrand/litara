## MODIFIED Requirements

### Requirement: API exposes a series detail endpoint

The system SHALL provide a `GET /api/v1/series/:id` endpoint that returns the full detail for a single series. The response SHALL include the series `id`, `name`, `totalBooks` (nullable), all author names (deduplicated union across all owned books), an ordered list of owned books in the series, and an ordered list of `SeriesSlot` records for unowned positions. Each owned book entry SHALL include `id`, `title`, `sequence` (nullable), `hasCover` (boolean), `coverUpdatedAt` (ISO string), `formats` (string array), `publishedDate` (nullable ISO string), `pageCount` (nullable), and `publisher` (nullable). Each slot entry SHALL include `id`, `title`, `sequence` (nullable), `authors` (string array), and `hasCover` (boolean, true when `coverData` is not null). Both arrays SHALL be ordered by `sequence ASC NULLS LAST`, then by `createdAt ASC`. The endpoint SHALL be protected by `JwtAuthGuard`.

#### Scenario: Returns series detail with owned books and slots

- **WHEN** an authenticated user sends `GET /api/v1/series/:id` for a series that has both owned books and SeriesSlots
- **THEN** the response is 200 with `id`, `name`, `totalBooks`, `authors`, `books` (owned), and `slots` (unowned) arrays, each ordered by sequence

#### Scenario: Returns empty slots array when no enrichment has occurred

- **WHEN** an authenticated user sends `GET /api/v1/series/:id` for a series with no SeriesSlots
- **THEN** the response includes `slots: []`

#### Scenario: Returns 404 for unknown series

- **WHEN** an authenticated user sends `GET /api/v1/series/:id` with an id that does not exist
- **THEN** the system returns 404 Not Found

#### Scenario: Unauthenticated request is rejected

- **WHEN** an unauthenticated request is made to `GET /api/v1/series/:id`
- **THEN** the system returns 401 Unauthorized

## ADDED Requirements

### Requirement: Series Detail page shows a "Fetch Complete Series" button

The Series Detail page SHALL display a "Fetch Complete Series" button that is always visible, regardless of whether `totalBooks` is set or whether slots already exist. Clicking the button SHALL call `POST /api/v1/series/:id/enrich`, display a loading state during the request, and on success reload the series detail data (including any newly created slots). On failure the page SHALL display an error notification.

#### Scenario: Fetch button is always visible on the series detail page

- **WHEN** an authenticated user views any series detail page
- **THEN** the "Fetch Complete Series" button is visible in the page header area

#### Scenario: Clicking the button triggers enrichment and reloads slots

- **WHEN** the user clicks "Fetch Complete Series"
- **THEN** a loading state is shown, the enrich endpoint is called, and on success the page reloads series data including any newly created or updated slots

#### Scenario: Enrichment failure shows an error notification

- **WHEN** the enrich endpoint returns an error
- **THEN** an error notification is displayed and the page content remains unchanged

---

### Requirement: Series Detail page displays unowned books as ghost cards

The Series Detail page book strip SHALL display `SeriesSlot` entries as ghost cards interleaved with owned book cards, sorted together by sequence. A ghost card SHALL be visually distinct from an owned card: desaturated and reduced opacity, with a "Not in library" badge overlay. Ghost cards SHALL have a fixed width and height matching the owned book card dimensions. If a slot has `hasCover: true`, the cover SHALL be fetched from `GET /api/v1/series/slots/:id/cover` and rendered in the same position as an owned book cover; otherwise the generic book placeholder icon is shown.

#### Scenario: Ghost cards appear between owned cards in sequence order

- **WHEN** the series has owned books at sequences 1 and 3 and a slot at sequence 2
- **THEN** the book strip shows card at #1 (owned), card at #2 (ghost), card at #3 (owned), in that order

#### Scenario: Ghost card is visually distinct from owned card

- **WHEN** a ghost card is rendered
- **THEN** it has reduced opacity or desaturation and a "Not in library" badge

#### Scenario: Ghost card with cover displays the slot cover image

- **WHEN** a slot has `hasCover: true`
- **THEN** the ghost card renders the cover from the slot cover endpoint

#### Scenario: Ghost card without cover shows the placeholder icon

- **WHEN** a slot has `hasCover: false`
- **THEN** the ghost card renders the same book-placeholder icon as an owned card without a cover

---

### Requirement: Clicking a ghost card shows a copy popover

Clicking a ghost card SHALL open a popover (not a page navigation) containing the book's title, the authors as a comma-separated string, and a "Copy title & author" button. Clicking "Copy title & author" SHALL write `"<title> by <authors>"` to the clipboard and close the popover. Clicking outside the popover SHALL close it.

#### Scenario: Clicking a ghost card opens the popover

- **WHEN** an authenticated user clicks a ghost card in the series book strip
- **THEN** a popover appears showing the slot's title and authors

#### Scenario: Copy button writes title and author to clipboard

- **WHEN** the user clicks "Copy title & author" in the ghost card popover
- **THEN** the string `"<title> by <author1>, <author2>"` is written to the clipboard and the popover closes

#### Scenario: Clicking outside the popover closes it

- **WHEN** the ghost card popover is open and the user clicks outside it
- **THEN** the popover closes
