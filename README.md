# soul-standard

STANDARD: stable asset standard. Soul identity, origin, root and capability descriptions; no platform registration.

Maintenance entry points: [MODULE](MODULE.md), [Agent boundaries](AGENTS.md), [compatibility](COMPATIBILITY.md), [operation and recovery](RUNBOOK.md). Machine configuration: [module.json](module.json).

Actual construction: Standard production source authority has moved here; production build and 26/26 VM tests pass. See module.json for detailed evidence statuses; independent deployment and remote CI remain unaccepted.
Recommended role CIPHER; original Owner unchanged. Unconfirmed actual maintainer and independent acceptor mappings remain pending; role names are not accounts or audit qualifications.

```sh
python3 scripts/ci.py
python3 scripts/ci.py --product
python3 scripts/ci.py --release-ready
```

Default CI checks the maintenance contract; `--product` refuses to pass when no product command is registered. Readiness gates do not deploy or sign.

## Current checkpoint

See [construction status](CONSTRUCTION_STATUS.md) for current evidence, blockers, recovery material and remote coordination. This checkpoint is not a release.
