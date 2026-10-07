# Project Status — Click Quiz

## Current checkpoint — 7 October 2026, fashion release

**Normal live:** https://www.click-quiz.com/shopping/  
**Shareable review:** https://www.click-quiz.com/shopping/?preview=1

The accepted product is now ten visual women’s outfit choices with genuine friend style matching, not the historical grocery/deal quiz. Original AI-created imagery, no right/wrong taste. Verified live two-player comparison: seven matching choices produced 70%. Preview mode uses clearly labelled sample distributions and records no votes/analytics; links preserve preview context. Normal crowd stats use real opted-in ballots, with an early-launch state below twenty.

Latest verified gameplay release: `dpl_Dk8L3GJjo5sCT4KDEd9HbCx2WdmF`, GitHub commit `622643d6ed4ca5c0fbc4966c6e3895dab1ac6855` (all fashion banner placeholders removed). Detailed discussion: `logs/2026-10-07-project-log.md`.

**Operational:** immutable edition manifests and image assets; actual question exposure/answer/load events; owner-only recent, historical and source/cohort reports; reviews after ten eligible starts, processed by a five-minute database schedule. Original shared editions remain available. Daily ninety-day raw-record cleanup is active at 03:25 UTC and its initial run removed zero expired attempts. Questions and unrelated legacy tables are excluded.

**Prepared, not autonomous AI:** guarded 50/50 experiment functions and a dry-run-first candidate generator are implemented. No experiment is active. Paid AI execution and a deployed AI worker remain pending credentials, spending authorization and sufficient real data. The review schedule does not itself generate new questions.

**Business baseline:** no paid traffic, live ads, measured revenue/profit or statistically useful player baseline. QA/preview are excluded from business claims. Monetization is deferred. All visible fashion ad placeholders are removed; the next phase is traffic and audience development. No paid acquisition or posting is authorized. Source synchronization is resolved. Ninety-day analytics deletion is explicitly approved and now scheduled daily at 03:25 UTC; questions and legacy tables are excluded.

## Latest direction — traffic first

User explicitly paused monetization and requested removal of all banner placeholders from the current fashion landing, question and result screens, including preview mode. Outfit images, immutable question editions, sharing and analytics are preserved. Google Ad Manager inspection stopped without account changes.

## Latest handoff checkpoint

User is exploring audience growth separately. No paid traffic, posts or persona launched. Current fashion release is live and synchronized to GitHub main. PR #1 merged as `0e87eda2613e25e4c8b26387518c53ecf0719abe`; its Git-triggered Vercel production deployment is Ready and assigned to www.click-quiz.com. All 51 release files matched the reviewed release; six regression tests passed. Only the approved obsolete `harry-potter.html`, `quiz.html` and `feed.xml` were removed (public routes verified 404). Repository history and old shopping shared links are preserved.

PR: https://github.com/mauverse-ui/Click-Quiz/pull/1
Deployment: https://vercel.com/mauverse-uis-projects/click-quiz/9QESJNtSRwtDYypjcCUvP89QcpkE

Vercel CLI installed at user scope and official Vercel plugin installed for Codex. MCP endpoint `https://mcp.vercel.com` configured in the user Codex config; OAuth succeeded. CLI 62.7.0 authenticated as mauverse-ui. Official vercel@openai-curated plugin is installed/enabled. A reload is needed to expose MCP documentation/team tools in this chat.

## Historical first release — superseded product, retained for old links


Last verified: 7 October 2026. Reactivated at the user's explicit request.

## Current release

**Live for phone review:** https://www.click-quiz.com/ and https://www.click-quiz.com/shopping/

The fresh shopping edition asks “How sharp are your shopping instincts?” Ten original English/euro challenges have deterministic official answers, explanations, progress, a /10 score, answer review, replay, and version-pinned challenge links. No account, artificial crowd statistics, IQ claims, AI calls per answer, or unrelated quiz links.

Latest Vercel production deployment: `dpl_24J4ygxb8MB23FPCPZhhJmZZ5kMf`.
Inspection: https://vercel.com/mauverse-uis-projects/click-quiz/24J4ygxb8MB23FPCPZhhJmZZ5kMf
The production root is the live GitHub repository root (not this workspace's `build/`). `build/` contains the release files maintained here. Unrelated remote prototype pages were preserved. Homepage replaced with shopping edition; legacy advertising service worker retired.

**Latest user ad direction:** clearly labelled banner placeholders only for review. Responsive 300×250 previews appear below the landing CTA, on challenges 3 and 6, and on results. No active publisher scripts, paid traffic, deposits, domain purchases, or paid service upgrades.

## Database and measurement

Existing Supabase project `roayyfrgofikkvihimkf` was restored by the user and is accessible. Applied additive migration in `supabase/shopping-launch.sql`:

- `cq_versions`: immutable-by-release content snapshot `shopping-v1`; all ten questions match the deployed JSON exactly.
- `cq_attempts`, `cq_events`: private tables with RLS and no anonymous table reads or writes.
- `cq_record_events`: narrowly granted anonymous RPC; validates version, IDs, bounded batches, campaign fields, question numbers, answer choices and sequence limits. Repeated event sequences are idempotent. Completion score is recalculated from official answers, requiring answer events.
- Opt-in analytics record campaign/UTM attribution, version, shown/answered questions, completion, sharing actions, and referred arrivals. Random referral codes differ from private attempt IDs. No names or emails requested. Browser choice/optional resume state uses session storage. Decline stops collection and clears saved attempts.
- Quiz uses the reviewed static snapshot for fast loading and remains playable if the database is unavailable. Never edit `shopping-v1` in place; publish a new version and retain old shared editions.
- Owner-only CSV-ready reporting query: `supabase/shopping-report.sql`. A validation query was saved in Supabase SQL Editor: https://supabase.com/dashboard/project/roayyfrgofikkvihimkf/sql/b6cf1656-2451-4e7e-83b2-8f5805a71c13

Anonymous analytics remain a consented sample and are not fraud-proof billing evidence. No visitor profitability is established. The required business test remains: initial-session revenue must cover acquisition cost before counting referral upside; reconcile network reports only at their supported dimensions.

## Verification

- Independent arithmetic and content tests pass: `node --test tests/shopping.test.cjs`; script syntax check passes.
- Mobile browser inspection at 390×844 and 320×740: no horizontal overflow; placeholders remain separated from answer controls.
- Full playthroughs: 10/10, 7/10, and final placeholder build 2/10 all match chosen answers. Answer lockout, explanations, review and replay controls inspected.
- Production opt-in attempt persisted 10 answer events and score 7. API validation persisted score 10. Duplicate batches created no duplicate rows; invalid question rejected; anonymous private-table reads and content writes denied.
- Production copy-link action succeeded and displayed the actual URL. Link keeps `v=shopping-v1`; referred browser arrival and play persisted with a matching parent referral. Native share integration is present; a completed share through a third-party app was not tested.
- Consent-declined complete final-build playthrough tested; database query confirmed zero attempts for validation campaign `declined_review`.
- Homepage and `/shopping/` serve the review build publicly with no login. Production CSP restricts scripts to this origin. No external font or gameplay SDK dependency.

## Publisher access verified (not activated)

**Monetag:** www.click-quiz.com, site ID `3365610`, Verified. Six zones: Vignette `11126956`, In-Page Push `11126868`, Popunder `11126905`, Direct Link `11128393`, Push `11126906` and `11129517`. Bare click-quiz.com has separate unverified site `3365606`. Existing formats do not include a standard in-flow 300×250; Vignette is an overlay. Dashboard left open. Latest user specifically requested placeholders, so none of these tags were added.

**Google Ad Manager:** opened successfully in Chrome's Chris profile. Network **Hombre Cave, 22773564060**. Both the Chris and Maurits accounts appear Active / Administrator. Sites list empty; no Click Quiz ad unit found among three generic Ad Exchange units. Linked accounts show Active AdX APAC display, in-app and video connections; AdSense links empty. No recent dashboard delivery results for September 7–October 6. Active links do not establish Click Quiz site approval, ad fill or revenue. Google dashboard left open; no settings or inventory changed.

Historical Adsterra approval email reported to this chat is not current dashboard verification and was not used to enable ads.

## Remaining items

1. User reviews the live quiz and labelled ad placement on their phone. No second quiz or beauty/Instagram persona was built; those were exploration only.
2. **Retention active:** the initial approval-review block was resolved by explicit user approval. `cq-analytics-retention` is active daily at 03:25 UTC, calling `cq_prune_analytics()` to delete CQ attempts older than 90 days and dependent events/ballots. Quiz versions/questions and unrelated legacy tables are excluded.
3. **GitHub synchronization resolved:** browser upload permission was enabled by the user. The complete release and assets, database scripts, tests, status and log were uploaded, byte-compared, and merged through PR #1. The resulting Git-triggered production deployment was verified against merge `0e87eda`; no force push or unrelated deletion occurred.
4. Before commercial monetization, resolve hosting plan: current Vercel team is Hobby. Official policy restricts Hobby to personal non-commercial use (https://vercel.com/docs/plans/hobby ; https://vercel.com/docs/limits/fair-use-guidelines). No paid upgrade authorized or purchased. Real ad integration also needs provider-specific consent/site/inventory setup and a measured traffic budget.

## Historical context

Earlier records described a paused consensus/voting prototype (August 2026). Those assumptions and seeded-vote scoring do not govern this shopping release. The historical `quiz-master` skill was unavailable in configured locations; implementation followed the user's current explicit launch brief. No legacy database tables were migrated destructively.
