# Contributing

Use Flutter 3.47.7 and Node.js 24. Keep dependencies locked. Run the verification commands in README.md before opening a pull request.

Keep real patient files, credentials, vendor SDK binaries and signing keys out of issues, source control and CI artifacts. Use generated test fixtures. New adapters must pass the scanner contract checks and explicitly document supported models, firmware, operating systems, SDK licensing, and hardware test evidence.

Do not mark a vendor adapter available based on a demo or file import. Preserve original imported files. Any new decoder must reject unsupported formats and enforce dimension/frame/file-size limits before allocation.

The original code is Apache-2.0. Contributions must be compatible with that license; review vendor terms separately.
