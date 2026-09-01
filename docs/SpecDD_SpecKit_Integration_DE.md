# Integrationsmatrix: SpecDD × GitHub Spec Kit für MitM-2

Dieses Dokument definiert, wie im `mitm-2` Projekt die Architekturspezifikation (SpecDD) und die Featurespezifikation (GitHub Spec Kit) zusammenarbeiten.

- **SpecDD** → Architektur-First, System-Intent, große Module (Collector, Transformation, Delivery, Scheduler).
- **Spec Kit** → Feature-First, schnelle Iteration, kleine Changes (z.B. ein neuer Collector, eine spezifische Mapping-Regel).

## 1. System-Ebene (SpecDD) vs. Feature-Ebene (Spec Kit)

| Ebene                       | Artefakt                                  | Werkzeug | Zweck                                   |
| --------------------------- | ----------------------------------------- | -------- | --------------------------------------- |
| **System-Intent**           | `.sdd` Specs (Root & Modul-Level)         | SpecDD   | Architektur, Domain, Security, Layering |
| **System-Architektur**      | `architecture.md`, `concept_mitm_aggregator.md` | SpecDD | Orchestrierung, Envelope Encryption, DB |
| **System-Governance**       | `.sdd` (Must / Must not / Forbids)        | SpecDD   | Security-Normen (PII), Puffer-Logik     |
| **Feature-Intent**          | Feature-Spec (Markdown)                   | SpecKit  | Isolierte Änderungen (z.B. neuer API-Collector) |
| **Feature-Planung**         | Plan-Dokument / Issue                     | SpecKit  | Tasks, Scope, Acceptance Criteria       |
| **Feature-Implementierung** | Tasks                                     | SpecKit  | AI-freundliche Umsetzung                |
| **Feature-Änderungen**      | Deltas                                    | SpecKit  | Versionierung einzelner Features        |

## 2. Integrationslogik (Wer überschreibt wen?)

| Bereich                  | Quelle  | Regel                                             |
| ------------------------ | ------- | ------------------------------------------------- |
| **Architektur**          | SpecDD  | SpecDD ist _Single Source of Truth_.              |
| **Security (Encryption)**| SpecDD  | SpecKit darf die Envelope Encryption nicht umgehen.|
| **Collectors**           | SpecKit | SpecDD definiert das Interface/Layer, SpecKit liefert konkrete Collectors (z.B. Kafka, CSV). |
| **Transformations**      | SpecKit | SpecDD definiert die Mapping-Engine, SpecKit liefert Mapping-Regeln. |
| **Delivery / Retry**     | SpecKit | SpecDD definiert die Zustellung, SpecKit definiert spezifische Retry/DLQ Features. |
| **Persistenzmodell**     | SpecDD  | SpecKit darf Tabellen für Features ergänzen, aber nicht die Core-DB-Struktur aufbrechen. |

## 3. Synchronisationsregeln (Drift vermeiden)

| Situation                       | Aktion                                  | Werkzeug |
| ------------------------------- | --------------------------------------- | -------- |
| Neues Feature (z.B. Collector)  | SpecKit-Spec → Tasks → Implement        | SpecKit  |
| Feature beeinflusst Architektur | SpecKit-Feature erzwingt Update der `.sdd` | SpecDD   |
| Architekturänderung             | SpecDD → neue SpecKit-Features ableiten | SpecKit  |
| Konflikt zwischen Specs         | SpecDD gewinnt                          | SpecDD   |
| Neue Normen (z.B. Logging)      | SpecDD aktualisieren → SpecKit anpassen | Beide    |

## 4. Artefakt-Mapping für MitM-2

| MitM-2 Bereich  | SpecDD                      | Spec Kit                            |
| --------------- | --------------------------- | ----------------------------------- |
| **Collector**   | ✔ Layer-Design, Interfaces  | ✔ Neuer Kafka-Collector, ORA-Update |
| **Transform**   | ✔ Validation & Rules Engine | ✔ JSON-Mapping, Custom Filter       |
| **Delivery**    | ✔ SaaS-REST Anbindung       | ✔ Payload-Assembling Anpassung      |
| **Security**    | ✔ Envelope (AES-GCM) Design | ✔ Feature-Level Security Checks     |
| **Storage**     | ✔ PostgreSQL Pooling & Schema | ✔ Feature-spezifische Tabellen  |
| **Scheduler**   | ✔ Orchestrierung, IPC       | ✔ Neuer Cron-Job Parameter          |

## 5. Integrationsmatrix

| Kategorie               | SpecDD | Spec Kit |
| ----------------------- | ------ | -------- |
| System-Intent           | ✔      | ✖        |
| Architektur             | ✔      | ✖        |
| Governance / Security   | ✔      | ✖        |
| Feature-Intent          | ✖      | ✔        |
| Feature-Planung         | ✖      | ✔        |
| Feature-Implementierung | ✖      | ✔        |
| Drift-Kontrolle         | ✔      | ✔        |

## 6. Code-Qualität & Standard-Baseline

Alle Spec Kit Features MÜSSEN die strikten Basisstandards einhalten, die in der `mitm-2.sdd` und `GEMINI.md` definiert sind. KI-Agenten und Entwickler dürfen keinen Code generieren, der diese verletzt:
- **Sprache:** Alle Code-Dokumentationen und Kommentare müssen auf Englisch sein.
- **Lizenzierung:** Jede Quelldatei muss den standardisierten SPDX-Header (C++-Style Blockkommentar) mit der Apache-2.0-Lizenz enthalten.
- **Modularität:** Jede Schichtkomponente wird als eigenständiges Go-Binary mit eigener `go.mod` kompiliert.
- **Secrets:** Der Master Key (KEK) wird niemals auf der Festplatte gespeichert; Kindprozesse rufen ihn dynamisch über den IPC Unix Socket ab.
