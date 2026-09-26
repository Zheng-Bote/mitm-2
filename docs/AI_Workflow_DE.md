# AI-Agent Instruktionen: SpecDD × GitHub Spec Kit Workflow

Dieses Dokument bricht die Vorgaben aus `docs/SDD-Howto_en.md` und `docs/SpecDD_SpecKit_Integration_EN.md` in konkrete, ausführbare Prozessschritte für KI-Agenten herunter. Es dient als Handlungsleitfaden für die Feature-Entwicklung im `mitm-2` Projekt.

## 1. Rollenverteilung & Hierarchie

- **SpecDD (`.sdd`) = Die Verfassung:** Single Source of Truth für Architektur, Security (Envelope Encryption, PII), Datenbank und Layering. Ändert sich selten. Darf von Features **nicht** gebrochen werden.
- **Spec Kit (Markdown) = Der Arbeitsauftrag:** Flow-Forward Feature-Entwicklung (z.B. neuer Collector, neues Mapping). Iterativ, detailliert und auf ein spezifisches Ziel fokussiert.

## 2. Der Agentic Workflow (Flow-Forward)

KI-Agenten arbeiten Features sequenziell nach folgendem Muster ab, um Code-Drift zu vermeiden:

### Schritt 1: Specify (Requirements)
*   **Auslöser:** `/speckit.specify`
*   **KI-Aktion:**
    *   Feature-Branch erstellen (z.B. `feature/ticket-123`).
    *   Speicherort für Spec Kit bestimmen:
        *   Cross-Layer (betrifft mehrere Repos): `specs/features/<name>/` im Root-Repo.
        *   Isoliert (betrifft ein Repo): `specs/` im jeweiligen Komponenten-Repo.
    *   **Ergebnis:** Eine Markdown-Feature-Spec mit klaren Akzeptanzkriterien (PRD).

### Schritt 2: Plan (Design & Architektur-Check)
*   **Auslöser:** `/speckit.plan`
*   **KI-Aktion:**
    *   **Spec Chain auflösen:** Identifiziere den *Target-Pfad* (Scope) des Features (z.B. `core-layer/mitm_http-server/`).
    *   Lies die Spec-Chain hierarchisch von Root (`mitm-2.sdd`) über den jeweiligen Layer (inkl. via `References` verknüpfter Architektur- und Security-Specs) bis zur lokalen Komponente ein.
    *   **Architektur-Check:** Prüfe den Feature-Entwurf gegen alle geerbten Constraints (Werden Layer-Grenzen respektiert? Werden geerbte `Must not`-Regeln bezüglich PII oder DB-Pooling verletzt?).
    *   **Ergebnis:** Ein Architektur-Plan (Technical Spec), der das "Wie" strikt innerhalb der vererbten SpecDD-Grenzen (Scope & Authority) entwirft.

### Schritt 3: Tasks (Arbeitspakete definieren)
*   **Auslöser:** `/speckit.tasks`
*   **KI-Aktion:**
    *   Plan in atomare Arbeitspakete (Tasks) zerlegen.
    *   **Pflicht:** Jeder Task MUSS das betroffene Repository/Modul explizit benennen (z.B. Code-Änderung in `collector-layer/mitm_collector_pg`).
    *   **Pflicht:** Reihenfolge beachten: Schnittstellen & Verträge zuerst.
    *   **Ergebnis:** Eine geordnete Liste sequenziell abarbeitbarer Agent-Tasks.

### Schritt 4: Implement (Code generieren)
*   **Auslöser:** `/speckit.implement`
*   **KI-Aktion:**
    *   Abarbeiten des nächsten offenen Tasks.
    *   Code schreiben und Tests hinzufügen.
    *   **Code-Standard-Check (Zwingendes Quality Gate für die KI):**
        *   [ ] Sind Doku und Kommentare auf Englisch?
        *   [ ] Hat jede Quellcode-Datei den SPDX-Header (Apache-2.0)?
        *   [ ] Bleiben Secrets (Master Key / KEK) ausschließlich im RAM (via IPC bezogen) und niemals auf der Disk?
        *   [ ] Bleibt das Modul eigenständig (mit eigener `go.mod`)?
    *   **Ergebnis:** Code-Deltas für den Review.

### Schritt 5: Converge (Überprüfung & Iteration)
*   **Auslöser:** `/speckit.converge`
*   **KI-Aktion:**
    *   Vergleich des IST-Zustands (Code) mit dem SOLL-Zustand (Spec Kit Feature Spec + SpecDD `.sdd` Vorgaben).
    *   Prüfung: Fehlt Error-Handling? Fehlen Edge-Cases? Wurden Security-Normen vergessen?
    *   Falls unvollständig: Neue Tasks generieren, an die Taskliste anhängen und zurück zu *Implement*.
    *   Falls vollständig: Feature ist logisch abgeschlossen.

### Schritt 6: Release (Abschluss)
*   **KI-Aktion:**
    *   `CHANGELOG.md` in allen betroffenen Komponenten aktualisieren.
    *   Vorbereitung für Push & Pull Request.

---

## 3. Artefakt- und Lifecycle-Übersicht

Diese Matrix vereint den abstrakten Entwicklungszyklus mit den konkreten SpecKit-Kommandos und Artefakten:

| Phase | KI-Befehl | Haupt-Artefakt | KI-Quality Gate (Check) | Resultat |
| :--- | :--- | :--- | :--- | :--- |
| **1. Intake & Requirements** | `/speckit.specify` | Feature Spec (Markdown) | Problem, Scope, User & Non-Goals sind klar definiert und testbar. | KI weiß, *was* umgesetzt werden soll. |
| **2. Design & Architecture** | `/speckit.plan` | Architekturentwurf | Abgleich mit `.sdd` (SpecDD) ist konfliktfrei; Layering & Security bestätigt. | KI weiß, *wie* das System gebaut wird. |
| **3. Tasking** | `/speckit.tasks` | Agent Task Plan | Tasks sind klein, repo-spezifisch, bounded und reviewbar. | KI hat kontrollierte Arbeitspakete. |
| **4. Implementation** | `/speckit.implement` | Code & Tests | Code erfüllt SpecDD-Baselines (SPDX, English, No-Secrets-on-Disk) exakt. | Feature wird realisiert. |
| **5. Testing & Review** | `/speckit.converge` | Delta / Review Report | Code matcht Feature-Specs und Architektur-Regeln restlos. | Abweichungen (Drift) eliminiert. |
| **6. Release & Learning** | *(Manuell / CI)* | Changelog, PR | `CHANGELOG.md` ist aktuell, CI/CD cross-repo Tests werden adressiert. | Feature ist merge-bereit. |
