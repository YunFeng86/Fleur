# Release Updates

Fleur's GitHub-distributed builds use a lightweight in-app update prompt. The
app reads GitHub Pages metadata and opens the matching GitHub Release page; it
does not download or replace the app automatically.

## Release Notes

Maintain user-facing notes continuously in `docs/releases/unreleased.md`.
Before publishing a tag, rename that file to the exact tag name, for example
`docs/releases/v0.1.5.md`, then create a fresh `unreleased.md` for the next
version.

Each archived release note file must include non-empty English notes:

```markdown
# Fleur v0.1.5

<!-- update-notes:en -->
- Fixed ...
<!-- /update-notes:en -->

<!-- update-notes:zh -->
- 修复 ...
<!-- /update-notes:zh -->

## Internal
- Optional maintainer-only notes.
```

`en` is the required fallback language. Other app locales fall back to English
when their matching notes are missing.

## Metadata

Release CI runs `tool/release/generate_update_manifest.dart`. It reads
`docs/releases/<tag>.md`, validates `update-notes:en`, computes release asset
checksums, writes `SHA256SUMS.txt`, and generates GitHub Pages metadata:

- `updates/stable/latest.json`
- `updates/stable/<tag>.json`
- `updates/beta/latest.json`
- `updates/beta/<tag>.json`

Tags containing `-alpha`, `-beta`, or `-rc` are published to the beta channel.
All other `v*` tags are stable.

## Local Check

After preparing release files locally, run the same generator before tagging:

```sh
dart tool/release/generate_update_manifest.dart \
  --tag v0.1.5 \
  --repository ZeyrMe/Fleur \
  --release-files release-files \
  --output build/update-pages \
  --release-body RELEASE_BODY.md
```

GitHub Pages must be configured to deploy from GitHub Actions.
