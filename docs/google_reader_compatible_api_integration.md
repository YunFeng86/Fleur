# Google Reader Compatible API Integration

Last updated: 2026-06-05

This document turns the protocol research into an implementation plan for
Fleur. The target is the modern Google Reader compatible API family, not the
retired Google Reader service.

## Decision

Add Google Reader compatible API support as a separate remote backend:

- `AccountType.googleReader`
- `lib/services/sync/google_reader/google_reader_client.dart`
- `lib/services/sync/google_reader/google_reader_sync_service.dart`
- `GoogleReaderRemoteArticleActionExecutor`

Keep repositories as local Isar persistence only. HTTP, auth, endpoint
quirks, pagination, and response parsing stay in the sync client/service layer.
UI surfaces continue to use backend capability and sync semantics matrices.

## First-Phase Scope

Supported in phase one:

- ClientLogin/API-password/token style providers such as FreshRSS, Miniflux
  Google Reader API, BazQux, FeedHQ, and The Old Reader.
- Account connection test and provider capability probing.
- Subscription and folder mirror into `Feed` and `Category`.
- Article fetch through global stream item IDs and batch item contents.
- Read/star state import and local-first writeback via `edit-tag`.
- `mark-all-as-read` for account/feed/folder streams when the provider supports
  it.
- Outbox replay for remote article actions.

Deferred:

- Inoreader OAuth flow. Its profile is reserved, but it should not be treated
  as a ClientLogin provider.
- Feedbin native API. Feedbin is not a Google Reader compatible endpoint.
- Remote subscription structure writes such as add/delete/move/rename.
- Bidirectional custom article label synchronization.
- Social, comments, people/friend, share, like, and recommendation endpoints.

## Provider Profiles

The adapter should expose a provider profile instead of pretending there is a
single stable standard:

| Profile | Auth | Notes |
|---|---|---|
| `genericClientLogin` | ClientLogin + `Authorization: GoogleLogin auth=...` + `T` token | Fallback profile. |
| `freshRss` | FreshRSS API password | Base URL usually points at `api/greader.php`. |
| `minifluxGoogleReader` | Miniflux Google Reader credentials | POST endpoints require `T`; implementation is a subset. |
| `bazqux` | ClientLogin token | Large batch limits, broad compatibility. |
| `feedHq` | ClientLogin token + short-lived POST token | Feed folder is single-label. |
| `theOldReader` | ClientLogin token | JSON only, ObjectId-shaped IDs. |
| `inoreaderOAuth` | OAuth bearer token | Reserved for a later phase. |

Capability probing should validate, in order:

1. Auth succeeds and no password/token is logged.
2. `/reader/api/0/token` works when the profile needs write tokens.
3. `/reader/api/0/subscription/list` returns JSON subscriptions.
4. `/reader/api/0/stream/items/ids` accepts `output=json`.
5. `/reader/api/0/stream/items/contents` accepts a small item batch.
6. `edit-tag` and `mark-all-as-read` are available or explicitly disabled.

## Minimal Endpoint Set

| Endpoint | Use |
|---|---|
| `/accounts/ClientLogin` | Exchange username/password or API password for auth token. |
| `/reader/api/0/token` | Get write/CSRF token for compatible POST actions. |
| `/reader/api/0/subscription/list` | Mirror feeds and folder labels. |
| `/reader/api/0/tag/list` | Discover labels/states where available. |
| `/reader/api/0/unread-count` | Optional unread badge reconciliation. |
| `/reader/api/0/stream/items/ids` | Page through stream item IDs; IDs are strings. |
| `/reader/api/0/stream/items/contents` | Batch fetch article content; long IDs are strings. |
| `/reader/api/0/edit-tag` | Apply read/unread and starred/unstarred. |
| `/reader/api/0/mark-all-as-read` | Apply bulk read state by stream. |

Do not build phase-one sync around per-feed refreshes or `ot=now-30d`. Use a
global item ID set, unread/starred state sets, continuation paging, and periodic
reconciliation.

## Data Mapping

| Google Reader compatible object | Fleur model | Notes |
|---|---|---|
| Subscription `id`, feed URL, title, site URL | `Feed.remoteId`, `Feed.url`, `Feed.title`, `Feed.siteUrl` | `Feed.remoteId` is already `String?`. |
| Folder/user label stream | `Category.remoteId`, `Category.name` | First phase mirrors one effective category. Multi-folder feeds are a later design choice. |
| Item long or short ID | `Article.remoteId` | Treat as a provider/account-scoped string, not an integer or global ID. |
| `user/-/state/com.google/read` | `Article.isRead` | Remote state is authoritative during remote sync. |
| `user/-/state/com.google/starred` | `Article.isStarred` | Local-first actions replay through outbox. |
| User article labels | `Tag` | Deferred unless `Tag.remoteId` is added. |

`Article`, `Feed`, and `Category` do not need schema changes for phase one.
The first required identity change is in the outbox: entry actions must support
string IDs while preserving legacy Miniflux/Fever integer behavior.

## Required Code Areas

- `lib/services/accounts/account.dart`: add `AccountType.googleReader`.
- `lib/services/accounts/credential_store.dart`: reuse API token/basic auth
  storage keys by account type; do not add plaintext config storage.
- `lib/services/sync/outbox/outbox_store.dart`: add string-first
  `remoteEntryKey` and bulk `streamId`, keeping legacy `remoteEntryId`.
- `lib/services/actions/article_action_service.dart`: stop assuming all remote
  entry IDs parse as `int`; branch after capability gating.
- `lib/services/sync/remote_article_action_executor.dart`: parse legacy integer
  IDs inside Miniflux/Fever executors; add a Google Reader executor that sends
  string IDs directly.
- `lib/services/sync/remote_client_factory.dart`: build Google Reader clients
  from the account base URL and secure credentials.
- `lib/providers/service_providers.dart`: select the new sync service.
- `lib/services/sync/backend_capabilities.dart`: first phase should treat remote
  subscription structure as read-only/hidden, article read/star as deferred
  remote, export/local settings/offline cache as local-only.
- `lib/services/sync/backend_sync_semantics.dart`: account-wide refresh,
  remote paginated entries, read-only mirrored taxonomy, summary notifications.
- `lib/services/sync/backend_content_capabilities.dart`: client-side content
  enrichment only in phase one.
- `lib/ui/dialogs/add_account_dialogs.dart`, `lib/widgets/account_manager_dialog.dart`,
  `lib/widgets/account_avatar.dart`, and `lib/l10n/*.arb`: add account creation,
  labels, hints, and connection-test text.

## Tests

Required focused tests:

- Outbox JSON compatibility:
  - legacy `remoteEntryId: int` loads into both `remoteEntryId` and
    `remoteEntryKey`;
  - string `remoteEntryKey` round-trips;
  - `streamId` participates in mark-all-read dedupe.
- Remote action executors:
  - Miniflux/Fever still reject malformed non-numeric IDs;
  - Google Reader sends string IDs to `edit-tag`.
- Google Reader client:
  - ClientLogin parsing;
  - token parsing;
  - `subscription/list` response parsing;
  - item IDs and item contents parsing;
  - `edit-tag` request shape.
- Capability and sync semantics matrices cover `AccountType.googleReader`.
- Provider assembly returns the Google Reader sync service for the new account
  type.
- Account UI exposes the new backend without bypassing capability guardrails.

## Security Rules

- Store only tokens, API passwords, or OAuth secrets in `CredentialStore`.
- Do not put passwords or tokens in query strings.
- Do not include credentials, feed URLs with secrets, or category titles in logs.
- `Dio` debug logging must keep request/response bodies disabled.
- Connection-test failures should return sanitized diagnostics.

## Remaining Risks

- The protocol is a compatibility family, not a formal standard.
- Provider quotas and endpoint behavior can change without synchronized docs.
- Self-hosted behavior depends on server version and reverse-proxy setup.
- Old item read/star changes can be missed if sync relies on weak `ot` windows.
- Multi-folder feed semantics do not map perfectly to Fleur's single
  `Feed.categoryId`.
