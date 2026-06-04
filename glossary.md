# Glossary

| Term | Description |
| :--- | :--- |
| **KEK** | Key Encryption Key (Master Key) – The main key used to encrypt the DEKs. Never stored on disk, only kept in RAM at runtime. |
| **DEK** | Data Encryption Key – Individual key for each data fragment. Stored in the database encrypted with the KEK. |
| **Fragment** | Smallest unit of data from a source (e.g., a row of a CSV file). |
| **Package** | Aggregation of multiple fragments into a JSON document for SaaS delivery. |
| **Envelope Encryption** | Security concept where data is encrypted with a DEK, and the DEK is in turn encrypted with a KEK. |
| **Adapter** | Interface module for connecting data sources (CSV, REST, SQL, etc.). |
| **DLQ** | Dead Letter Queue – Storage for permanently failed records. |
| **Ingest** | Phase of reading and encrypting data fragments from source systems. |
| **Delivery** | Phase of sending aggregated JSON packages to the target SaaS platform. |
| **WAL** | Write-Ahead Logging – PostgreSQL logging method for ensuring data integrity, durability, and transaction safety. |
| **Idempotency** | Property of an API operation where executing it multiple times produces the same result. |
| **Cursors** | Progress markers to load only new data since the last run (prevents duplicates). |