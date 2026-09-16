## Feature Intent

Restore support for reading an encrypted JSON configuration (e.g., `config.enc`) to securely provide configuration values to the scheduler. Additionally, re-introduce the `encrypt-config` binary to allow generating these encrypted configuration files. 

The legacy source code for the `encrypt-config` binary and config reading logic can be found in `/home/zb_bamboo/Downloads/BMW/MitM/mitm-scheduler_old/mitm_scheduler-0.32.0/`.

## Requirements (EARS Syntax)

1. **When** the scheduler starts, **it shall** attempt to load its configuration from an encrypted JSON file.
2. **The system shall** resolve the path to the encrypted configuration file in the following priority order:
   - Command-line Parameter
   - Environment Variable (e.g., `MITM_CONFIG_FILE`)
   - Default Configuration File path (`./config.enc`)
3. **If** the configuration file cannot be loaded via Parameter, ENV, or Default path, **the system shall** fall back to internal default values.
4. **The system shall** continue to support the individual environment variables listed in the `README.md` (e.g., `MITM_DB_HOST`, `MITM_HTTP_PORT`), maintaining them in this form as ENV variables and respecting the priority order.
5. **If** the SSL certificates (`server.crt` and/or `server.key`) are not found at their configured paths, **the system shall** perform a fallback search in `<binary_dir>/.` and `<binary_dir>/certs/.`.
6. **The system shall** provide a standalone binary `encrypt-config` that takes a plaintext JSON configuration and produces the encrypted configuration file (`config.enc`), using the system's encryption mechanism.

## Scope

- Scheduler Layer (`scheduler/mitm_scheduler`)
  - Modification of configuration loading logic.
  - Porting the `encrypt-config` binary tool (`cmd/encrypt-config`) from the legacy repository.

## SpecDD Architecture Alignment (Drift Control)

Please confirm that this feature respects the global `mitm-2` constraints defined in `.sdd` files:

- [x] **Architecture:** The layered architecture is maintained (e.g. no direct bypass from Collector to Delivery).
- [ ] **Architecture:** Feature affects architecture: SpecKit feature forces update of the SpecDD .sdd
- [x] **Security:** Envelope Encryption (AES-GCM) is NOT bypassed for PII data. (Configuration encryption aligns with the project's security norms).
- [x] **Data Model:** Core PostgreSQL schemas remain intact (feature-specific tables are allowed).
- [x] **Standards:** SPDX headers, English documentation, and independent `go.mod` per layer will be maintained.

## Acceptance Criteria

- [ ] Scheduler successfully loads configuration from an encrypted `config.enc` file.
- [ ] Precedence logic for config file path is implemented correctly (Parameter > ENV > `./config.enc`).
- [ ] Fallback to internal defaults works if no config file is provided/found.
- [ ] Existing ENV parameters from README.md are still supported and parsed correctly.
- [ ] Fallback search logic for `server.crt` and `server.key` in `<binary_dir>/.` and `<binary_dir>/certs/.` is implemented.
- [ ] `encrypt-config` binary is built alongside the scheduler and correctly encrypts plaintext JSON configs.
- [ ] Existing `encrypt-config` source code (from legacy version 0.32.0) has been successfully adapted to the current project's codebase, ensuring consistent error handling and key management.
- [ ] CHANGELOG.md and README.md are up-to-date.
