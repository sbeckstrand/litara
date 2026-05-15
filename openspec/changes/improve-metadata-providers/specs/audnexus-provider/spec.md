## ADDED Requirements

> **Status: Beta.** Audnexus is a community-hosted service (`audnex.us`) with no SLA. Coverage is limited to Audible-released titles. ASIN is required — there is no title/author search fallback.

### Requirement: Audnexus provider fetches audiobook metadata via ASIN

The system SHALL provide an `AudnexusService` that queries the Audnexus REST API (`https://api.audnex.us` by default, overridable via `AUDNEXUS_BASE_URL` env var) using a book's ASIN as the primary lookup key. The service SHALL return a `MetadataResult` containing: title, authors, narrator (stored in categories as `"Narrator: <name>"`), description, publisher, series name, series position, genres, ASIN, and cover image URL.

#### Scenario: ASIN lookup returns full audiobook metadata

- **WHEN** a book has an ASIN and Audnexus returns a matching record
- **THEN** the service maps title, authors, narrator, description, publisher, series name, series position, genres, asin, and cover URL into a `MetadataResult`

#### Scenario: Narrator is stored in categories (tags)

- **WHEN** Audnexus returns a narrator for the book
- **THEN** the narrator is added to the `categories` array as `"Narrator: <name>"` (no dedicated column required)

#### Scenario: No ASIN returns null with a debug log

- **WHEN** a book has no ASIN set
- **THEN** the service logs a debug message ("Audnexus requires an ASIN — title/author search not supported") and returns `null`; no network request is made

#### Scenario: ASIN not found in Audnexus

- **WHEN** the ASIN lookup returns HTTP 404
- **THEN** the service returns `null` without throwing; the frontend shows a yellow toast ("Audnexus: no audiobook found for ASIN \<asin\>")

#### Scenario: Network or API errors are treated as soft misses

- **WHEN** the Audnexus API returns a 5xx error or the request fails
- **THEN** the service logs a warning and returns `null`; the metadata pipeline continues with other providers

---

### Requirement: Audnexus provider is registered in the metadata module

The system SHALL register `AudnexusService` in `MetadataModule` and add it to `PROVIDERS_CONFIG` with `id: MetadataProvider.Audnexus`, `requiresApiKey: false`, `envKey: null`, and `label: 'Audnexus (Beta)'`.

#### Scenario: Audnexus appears in provider configuration list

- **WHEN** an admin views the metadata provider configuration
- **THEN** "Audnexus (Beta)" appears as an available provider with no API key requirement indicated

#### Scenario: Audnexus is hidden in Search Metadata when book has no ASIN

- **WHEN** an admin opens the Search Metadata tab for a book that has no ASIN
- **THEN** Audnexus does not appear in the provider MultiSelect

#### Scenario: Search Metadata shows ASIN-only warning when Audnexus is selected

- **WHEN** Audnexus is selected as a search provider
- **THEN** an info note is shown: "Audnexus searches by ASIN only — title and author are ignored"

---

### Requirement: Audnexus genres and description are available as opt-in fields

The system SHALL include `audnexus` as a disabled-by-default assignment for the `genres` and `description` fields in `DEFAULT_FIELD_CONFIG`. These entries make Audnexus available in the field config editor; they are not active unless explicitly enabled by an admin.
