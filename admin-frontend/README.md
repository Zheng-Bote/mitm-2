# Admin Desktop Application for MitM Data Aggregator

## Description

The Admin Desktop Application for MitM Data Aggregator is a desktop application that allows users to manage the MitM Data Aggregator. It provides a user-friendly interface for monitoring system logs, managing cursors, and handling the dead-letter queue (DLQ). The application is built with Go and uses the Fyne GUI toolkit for the user interface. It communicates with the MitM Data Aggregator through a Unix domain socket.

[mitm_fe_cpp](https://github.com/Zheng-Bote/mitm_fe_cpp)

_see also:_ [concept_admin_frontend.md](./concept_admin_frontend.md)
### Key Rotation

The Admin Frontend allows administrators to rotate the Master-Key on-the-fly without service downtime. Under the "System / Settings" tab, unlocking the Key Vault exposes the Master-Key Rotation UI. You can generate a new cryptographically secure 32-byte key, and upon confirmation, the UI securely encrypts the new key with the current key via AES-GCM and dispatches it to the Scheduler backend.

