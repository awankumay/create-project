# Validation status — 21 October 2026

## Verified runtime result

[GitHub Actions run 39604270836](https://github.com/awankumay/create-project/actions/runs/39604270836) completed successfully for source commit `edd8caa73f3e28c1815a93bc3c7f3451957ac362`.

| Check | Result |
|---|---|
| Native PHP lint and Bash syntax | Passed |
| Installer dry-run, invalid input, target/symlink refusal | Passed |
| Full Laravel + Flutter project installation | Passed |
| Laravel API and Filament tests | 7 passed, 32 assertions |
| Flutter dependency resolution and Drift code generation | Passed |
| Flutter analyzer | No issues found |
| Flutter offline tests | 6 passed |
| Laravel boot/about and API route listing | Passed |

The verified run used Ubuntu, PHP 8.4.26, Laravel 13.38.0, and Flutter stable. Dependencies were resolved at installation time; generated project lockfiles are not part of this installer repository.

Backend tests include idempotent replay, changed-operation conflict, UUID overwrite refusal, auth/abilities/ownership, cursor validation, login/logout, positive rendering of the dashboard/read-only resource, and denial of panel access for non-admins.

Flutter tests cover database reopen persistence, lost acknowledgement with identical retry payload, account/server isolation, persistent 422 rejection, 401 reauthentication handling, and atomic pull/cursor rollback.

## Boundaries

The Flutter transport tests use an HTTP test client. Laravel tests independently validate real server/database behavior using the generated app and SQLite. These are not native-device end-to-end tests.

Windows executable compilation, Android APK compilation, OS secure-storage integration on physical devices, printer/scanner integration and concurrent MySQL request tests have not been run in this validation. Validate these on the target hardware before deploying business data. No production readiness, background-while-closed sync, encrypted draft database or granular enterprise RBAC is claimed.

## Local source checks

The editing environment has Bash, Python, Node and Git but no installed PHP, Composer or Flutter/Dart runtime. Bash syntax, Python compilation, template/OpenAPI parsing, diff checks and source inspection passed locally. Runtime verification above was performed by GitHub Actions, not by substituting a placeholder or mock installer locally.
