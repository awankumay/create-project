# Validation status

This document distinguishes source checks from runnable integration tests.

## Local environment

The editing environment has Bash, Python, Node and Git but no installed PHP, Composer or Flutter/Dart runtime. Attempts to obtain system packages/SDK metadata were blocked or unsuccessful. No complete installer run, Laravel boot, Flutter analyze/test, Windows build or Android build is claimed from that environment.

Bash syntax, Python compilation, template structure/OpenAPI parsing and source inspection are run locally. PHP source may additionally be syntax-parsed with a JavaScript PHP parser; this is not equivalent to PHP runtime tests.

## Automated verification

`.github/workflows/starter.yml` provisions PHP 8.4, Composer and Flutter stable on Ubuntu. It lints PHP/Bash, tests installer argument/target safety, generates a complete starter, runs backend tests and Flutter code generation/analyze/tests, then checks Laravel boot/routes. Consult actual GitHub Actions results for pass/fail; a committed workflow alone is not proof of success.

The Flutter transport tests use an HTTP test client. They validate client retry/persistence and isolation. Laravel tests independently validate server idempotency. A native-device end-to-end restart test, simultaneous MySQL request test and release build remain required before deploying business data.
