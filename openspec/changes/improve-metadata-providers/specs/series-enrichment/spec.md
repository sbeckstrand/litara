## MODIFIED Requirements

### Requirement: Hardcover is used as the primary enrichment provider when configured

The system SHALL query Hardcover first when `HARDCOVER_API_KEY` is set. The query SHALL search for a series by exact name match (`_eq`) against `Series.name`. If no result is returned, the system SHALL retry with a case-insensitive partial match (`_ilike`). The query SHALL retrieve each `book_series` entry's `position`, the book's `title`, `image { url }`, and `contributions { author { name } }`. The `books_count` field SHALL be used to update `Series.totalBooks`.

#### Scenario: Hardcover enrichment returns full series roster

- **WHEN** `HARDCOVER_API_KEY` is set and Hardcover returns series data for the given name
- **THEN** slots are created for unowned books using Hardcover data and `provider` is set to `"hardcover"`

#### Scenario: Hardcover falls back to ilike when exact match returns empty

- **WHEN** the exact-match query returns no series but an ilike query returns one
- **THEN** the ilike result is used for enrichment

#### Scenario: System falls back to Goodreads when Hardcover returns no data

- **WHEN** `HARDCOVER_API_KEY` is not set, or Hardcover returns no series data
- **THEN** the Goodreads series lookup is attempted

---

### Requirement: Goodreads is used as the last-resort enrichment provider

When Hardcover returns no series data, the system SHALL attempt to enrich via Goodreads. The system SHALL find any `Book` in the series that has a `goodreadsId`, fetch that book's Goodreads page, extract the series page link, then scrape the series page to obtain the ordered list of books. A WAF block (HTTP 403 or `GOODREADS_WAF_BLOCKED` response) SHALL be treated as a soft miss — the enrichment attempt returns `null` without throwing, and a 502 is returned only if no provider returned data. If no book in the series has a `goodreadsId`, the Goodreads path is skipped entirely.

#### Scenario: Goodreads enrichment succeeds from an existing goodreadsId

- **WHEN** Hardcover is unavailable and at least one book in the series has `goodreadsId` set
- **THEN** the Goodreads series page is scraped, slots are created for unowned books, and `provider` is set to `"goodreads"`

#### Scenario: Goodreads WAF block is treated as a soft miss

- **WHEN** the Goodreads request returns a WAF block (HTTP 403 or `GOODREADS_WAF_BLOCKED`)
- **THEN** Goodreads returns `null` rather than throwing; the pipeline treats this as no result from Goodreads

#### Scenario: Enrichment fails when all providers return no data

- **WHEN** Hardcover returns no results and Goodreads is blocked or no book has a `goodreadsId`
- **THEN** the response is 502 with a message indicating no metadata provider returned series data
