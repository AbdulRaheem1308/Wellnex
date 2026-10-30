# Wellnex mail incident: findings and release checklist

Review date: 2026-10-30 (IST). Repository: `AbdulRaheem1308/Wellnex`.
Local source: `C:\Users\rahee\.gemini\antigravity\scratch\stepify`.
Reviewed base commit: `7adbc06975ffae6446d2f0def1da3207bb9abf5d`.

## Incident finding

The SMTP diagnostic `wellnex_backend/test-smtp.js` contained a literal Gmail app password for the affected account. Git history introduced it in commit `38e2d8dbc8e133be6cb405bd24f74bbb24bbb631` on 2026-06-20. The credential value is intentionally omitted here.

The user reports approximately 63 unauthorized wallet-verification messages in Gmail Sent starting 2026-10-29 at 20:53 IST. Screenshots show messages through 22:39 IST, altered sender display names, unrelated recipients, and requests for wallet recovery phrases/private keys. This is phishing content.

Credential exposure is confirmed. Abuse of that credential is a plausible explanation, but source inspection and screenshots cannot establish which client or host sent the messages. They do not prove that OCI itself was compromised. Full message headers, Gmail activity, and server logs remain necessary for attribution.

The user reports revoking the old app password. The current application sends email through Resend/Brevo as `no-reply@joinwellnex.com`; it does not need the replacement Gmail app password. Do not put the replacement in source, GitHub, chat, or the mobile app. The optional diagnostic now reads `SMTP_USER` and `SMTP_PASS` from its environment and only verifies connectivity when explicitly invoked.

## Local changes

| Area | Change |
| --- | --- |
| Credential exposure | Removed the literal SMTP credential; added a narrow regression check; excluded the diagnostic from Docker builds. |
| Signing material | Staged removal of `release_keystore.jks` from Git tracking; kept the local file unchanged; ignored signing stores and key properties. This does not erase history. |
| Admin access | Removed the public fallback admin key; missing/default configuration fails closed. Added admin-key guards to previously exposed anomaly administration and achievement initialization. |
| OTP abuse | Exactly one phone/email identity per request; normalized email; atomic Redis verification; maximum five guesses; single-use code; five sends/hour with a 60-second resend cooldown; Gmail aliases share send quota. Redis failure rejects sends and production verification. |
| Identity ownership | Reject unverified social-provider emails; reject inactive accounts during token issuance; block changing login email/phone through ordinary profile updates until a verified identity-change flow exists. Existing identity values may still accompany profile saves. |
| Notification access | Updates/deletes now require both notification ID and authenticated user ID. |
| Provider errors | Resend structured errors trigger fallback; Brevo-only configurations can send. |
| Configuration | No JWT fallback; production requires distinct signing secrets of at least 32 characters. Configured admin key must meet the same minimum in the main backend. |
| Background jobs | Disable scheduled cron jobs in `WORKER_MODE=true` to avoid duplicate cron execution in the sample API/worker pair. Multiple API replicas still require a single scheduler or distributed lock. |
| Compose template | Replace embedded production secrets with required environment variables; bind database/Redis/pgAdmin host ports to localhost. |
| Dependencies | Update compatible packages and OpenTelemetry packages; override Multer to patched 2.5.x. Main production audit: 0 critical, 0 high, 10 moderate affected packages. Admin production audit: 0 findings. |
| CI/deployment | Add security tests and credential regression check; explicitly use disposable Redis for concurrency tests; validate admin backend; serialize deployment and deploy the tested commit SHA; refuse deployment over tracked server changes. |

The source credential check is a targeted regression barrier, not a complete secret scanner. It checks the SMTP helper and tracked signing-file names.

## Validation

- Initial targeted Nest run: 8 suites passed, 135 tests passed; 3 live Redis tests skipped locally.
- SMTP diagnostic tests: 3 passed, with mocked transport and no email sent.
- Admin middleware tests: 2 passed. Admin backend build passed.
- Final main backend build passed after the identity follow-up and Multer update.
- Final focused run: 4 suites passed, 83 tests passed (users, Redis, admin routes, production configuration). These overlap the earlier run; counts must not be added as unique tests.
- Changed/new backend TypeScript files passed ESLint after formatting corrections. Tracked and staged patches passed `git diff --check`; the local signing file remains present.
- Workflow and Compose YAML parse successfully.
- No production database migration, real email send, deployment, or Git push performed.
- Docker engine was unavailable locally. Live Redis atomicity tests require CI's disposable Redis service; full database E2E suite was not run against the developer's environment.

Remaining dependency advisories concern `firebase-admin`, Google Cloud clients/transitives, `uuid`, and `@nestjs/swagger`/`js-yaml`. Audit offers Firebase 14.5.0 as a major-version remediation for part of this chain. Evaluate that migration separately; the local audit result is not an all-clear certification.

## Before deployment

1. Preserve original suspicious messages and their full headers privately. Preserve OCI logs around 2026-10-29 20:53–22:39 IST (15:23–17:09 UTC), with a wider margin. Do not visit the wallet links or submit recovery phrases/private keys.
2. Complete Google account containment: change the account password if not already done; inspect security events, devices, connected apps, recovery settings, forwarding, filters, and delegation; remove unfamiliar access. Follow [Google's compromised-account guide](https://support.google.com/accounts/answer/6294825). Revoking one app password does not demonstrate that every other access path is closed.
3. Inspect the actual OCI runtime. The workflow runs Compose from `~/wellnex`, while checked-in source lives in `~/wellnex/source`; updating the repository template alone does not update the external Compose configuration. Confirm deployed SHA, image build contexts, environment-variable names, container logs, exposed ports, cron jobs, and mail provider activity. Do not paste secret values into chat or logs.
4. Configure strong, distinct `JWT_SECRET` and `JWT_REFRESH_SECRET`, plus a strong `ADMIN_API_KEY` shared by the intended admin client/backend. Set these through protected server configuration. Rotating signing secrets invalidates existing login sessions. Confirm actual email-provider credentials, sender verification, Firebase, Twilio, database, and Redis settings remain available to the correct services.
5. Review database credentials before changing Compose. Changing `POSTGRES_PASSWORD` on an existing data volume does not itself rotate the database account password; coordinate database-role and connection-string changes. Never delete production volumes as part of this fix.
6. Review the exposed Android keystore with the release owner. Determine whether it is an upload key or signing key and plan the appropriate recovery. Local untracking is not key rotation. Coordinate any Git-history cleanup with collaborators after credential revocation and evidence preservation; no force-push/history rewrite has been done.
7. Review and commit the local patch, including new tests and the staged keystore removal. Run CI on a branch/PR first. A push or merge to `main` triggers production deployment automatically, so finish OCI configuration checks before merging.
8. After deployment, verify health, one approved OTP request, rate-limit rejection, admin rejection without a key, ordinary profile saves, and notification ownership. Watch Gmail Sent and provider logs for recurrence. Do not reintroduce the revoked password during rollback.

## Scope limits and follow-up

This is a local source review and remediation, not a completed production forensic investigation. Gmail session state, OCI host integrity, deployed environment, remote Git history visibility/caches, and production logs were not verified. Additional work includes full repository/history secret scanning, resolving remaining dependency advisories, a verified contact-change flow, hashed refresh-token storage/rotation review, and authorization checks across realtime gateways. No claim is made that every possible codebase vulnerability has been eliminated.
