# Core-Layer

| Component | Description                           | Repo                                                                     |
| --------- | ------------------------------------- | ------------------------------------------------------------------------ |
| HTTP      | API Gateway & **ECS Supervisor** (PID 1). Orchestrates IAM & Scheduler. | [mitm_core_http](https://github.com/Zheng-Bote/mitm_core_http)           |
| Scheduler | Orchestrates the whole MitM pipeline & acts as the secure Crypto Vault. | [mitm_core_scheduler](https://github.com/Zheng-Bote/mitm_core_scheduler) |
| IAM       | IAM Server for the MitM pipeline. Validates roles and sessions. | [mitm_core_iam](https://github.com/Zheng-Bote/mitm_core_iam)             |

## Architectural Design

The Core-Layer is designed for **AWS ECS** deployment as a unified module using the Supervisor Pattern:
1. **PID 1 (HTTP-Core)** starts immediately to answer AWS ALB Health Checks.
2. It natively spawns the **IAM** and **Scheduler** child processes.
3. **Zero-Trust Memory Isolation**: The HTTP-Core never loads the `MASTER_KEY` into its memory footprint. Instead, it delegates all Database configuration fetching and cryptographic operations (e.g., DEK encryption for roles) via strict **Unix Domain Sockets (IPC)** to the Scheduler vault.
