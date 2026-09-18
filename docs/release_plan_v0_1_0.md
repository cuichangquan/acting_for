# ActingFor 0.1.0 Actual Release transaction plan

D231 readiness preparation only. No publication has occurred. Execute only after a separate explicit user approval. Version remains `0.1.0`, tag remains `v0.1.0` (D075). Release automation remains disabled / unconfigured.

## Human confirmation before execution

- Explicit approval for repository public visibility, RubyGems publication, `v0.1.0` tag creation / push, and GitHub Release publication.
- Confirm the intended RubyGems account / initial owner and authentication method. Local `~/.gem/credentials` is not configured in the verified environment; no API key was generated or displayed. Account access, publish scope, and any required MFA must be established before irreversible publication. Trusted Publishing / MFA policy is not chosen by D231.
- Recheck Rails 8.0 support if publication is delayed beyond its security support end (2026-11-07); a matrix change requires a separate Decision.

## Exact README changes for the release transaction

Prepare a reviewable change before publication without claiming a completed release:

1. Change Quick Start installation from GitHub main to `gem "acting_for", "~> 0.1.0"`; preserve the Rails 8.0 `json < 3` compatibility line and the verified Rails / migration / Ruby example commands.
2. Remove private repository access and HTTPS-to-SSH rewrite instructions, including the cleanup command; RubyGems installation needs neither.
3. Replace the pre-release introduction and main / lock explanation with the released-version installation explanation. Keep a truthful pending-publication status until RubyGems succeeds.
4. After RubyGems confirms 0.1.0, replace `Status: ... Not released`, the initial not-published sentence, and the Project documents / license-section Not released sentences with factual RubyGems 0.1.0 availability and a link to its gem page. Preserve all API / security boundaries.

The status update is factual documentation, not a version change. Release Notes remain draft until the GitHub Release is published. Remove their two draft / not-yet-released introductory sentences and change the conditional installation language to factual availability for the actual GitHub Release body.

## Execution order

1. Confirm main / origin/main / GitHub main equality, clean status, final D231 CI success (all five jobs), exact-name availability, absent tag / Release, support status, and the explicit approval above. Verify intended RubyGems account and selected authentication method without printing secrets **before any visibility / publication action**.
2. Make the repository public; verify unauthenticated homepage, source, README, docs, LICENSE, and issue links. Stop if visibility / link verification fails.
3. Commit / push the prepared release-facing README with truthful pending-publication status. Wait for all five CI jobs green. Pin this source SHA as artifact source; no runtime changes are permitted during the transaction.
4. Build with `gem build --strict acting_for.gemspec`. Audit the file list and metadata, record byte size / SHA256, and verify artifact installation if packaged content differs from the D231 artifact. Recheck RubyGems exact-name / version absence immediately before push.
5. Publish that exact artifact to RubyGems using the approved authentication method. This is the first irreversible distribution step. Verify RubyGems API version `0.1.0`, download the distributed artifact, compare SHA256, and check normal RubyGems installation. Do not blindly retry after a timeout; check remote state first.
6. Update README to factual released availability and commit / push. Wait for all five CI jobs green. Verify no production / dependency / packaging change from the artifact source, apart from the intended README status update; record both SHAs. The packaged README can truthfully say pending at build time while repository README reports subsequent publication.
7. Create / push `v0.1.0` at the final release-facing main commit (including factual README), recording artifact-source SHA and artifact SHA256 in the Release body. Confirm remote tag points to that commit. The distributed runtime contents must match this commit; only the documented README status differs. Do not move / overwrite an existing tag.
8. Create GitHub Release `v0.1.0` with the finalized body from `release_notes_v0_1_0.md` (formal publication target: GitHub Releases); include artifact provenance / checksum. Verify public tag, Release, installation, links, and all five CI jobs.
9. Update CURRENT_STATE / PROGRESS with actual publication evidence, Latest Decision only if separately approved, and final clean status. Commit / push any state docs and wait for CI. Report artifact source, tagged SHA, final main SHA, RubyGems / Release URLs and checksum.

RubyGems and GitHub cannot be made a single atomic transaction. Publishing the gem before the tag avoids a release tag for an unpublished gem; if a later step fails, resume only the incomplete step using recorded SHAs / checksum. Never repush the same version, overwrite a tag, or yank as an automatic rollback. Any ownership / version / policy change needs explicit approval.

Reference: [RubyGems publishing guide](https://guides.rubygems.org/publishing/). D231's checksum describes the pre-publication artifact verified by this Gate; README changes require a fresh build and checksum during actual release. D231 completion main HEAD is the current release candidate; the approved transaction's README commits determine the eventual tagged commit.
