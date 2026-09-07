# Entwickler-Guide: SpecDD & GitHub Spec Kit

Willkommen im `mitm-2` Projekt! Wir nutzen eine Kombination aus **SpecDD** (Architektur-Wahrheit) und **GitHub Spec Kit** (Feature-Entwicklung), um das System robust zu halten und gleichzeitig schnell neue Funktionen zu bauen.
Dieser Guide erklärt dir, wie du als Entwickler oder KI-Agent damit im Alltag arbeitest.

## Warum zwei Frameworks?

- **SpecDD (`.sdd` Dateien):** Ist das "Grundgesetz" des Projekts. Es definiert Architektur-Schichten, harte Security-Vorgaben (wie Verschlüsselung) und Modulgrenzen. Es ändert sich selten.
- **GitHub Spec Kit (Flow-Forward Spec):** Ist der strukturierte "Arbeitsauftrag". Wenn du etwas Neues bauen willst, nutzen wir einen iterativen, Agenten-gesteuerten Prozess (Plan -> Tasks -> Implement -> Converge), um das Feature sicher durch alle betroffenen Repositories/Komponenten zu führen.

## Der Flow-Forward Workflow (Agentic SDD)

Da unser System aus mehreren Komponenten mit jeweils eigenen GitHub-Repos besteht (z. B. `mitm_collector_pg`, `mitm_transformation`), orchestrieren wir Feature-Entwicklungen zentral aus dem Root-Repo. Dies verhindert Architektur-Drift und unübersichtliche Pull Requests.

Wir nutzen hierfür Agentic-Befehle (z. B. via Antigravity).

### 1. Rahmenbedingungen checken (SpecDD lesen)

Bevor du startest, verschaffe dir einen groben Überblick über die `.sdd` Dateien (z.B. `mitm-2.sdd` im Root). Sie verraten dir, was du tun **darfst** und was absolut **verboten** ist.

### 2. Spezifizieren & Planen (Design-Phase)

Bevor Code oder Specs geschrieben werden, wird durch den Agenten ein **Feature-Branch** (z. B. `feature/issue-42`) im betroffenen Repo erstellt.

**Ablageort der Spec:**
- **Schichtübergreifende Features** werden zentral als Spec-Verzeichnis im Root-Repo unter `specs/features/<feature-name>/` angelegt.
- **Isolierte Features**, die nur eine einzige Komponente betreffen, verbleiben zwingend in den `specs/` Ordnern der jeweiligen Komponenten-Repos (z.B. `delivery-layer/mitm_delivery/specs/...`).

- **`Run /speckit.specify`**: Der Agent (nachdem er den Branch erstellt hat) legt das neue Verzeichnis für dein Feature an und hilft dir, die initialen Anforderungen (Akzeptanzkriterien) zu definieren.
- **`Run /speckit.plan`**: Der Agent analysiert die Anforderungen gegen die `.sdd`-Dateien (global und lokal) und formuliert einen Architektur-Plan. Hier wird definiert, **wie** die betroffenen Schichten miteinander interagieren (z. B. Collector liefert JSON, Transformation mapped es).

### 3. Aufteilung & Vorbereitung (Work Breakdown)

- **`Run /speckit.tasks`**: Der Architektur-Plan wird in konkrete Teilaufgaben übersetzt. **Wichtig für dieses Monorepo:** Die Tasks müssen explizit definieren, in welcher Sub-Komponente / welchem Repo welcher Code geändert werden muss (z. B. "Ändere Interface in `collector-layer/mitm_collector_pg`"). Die Reihenfolge ist bindend (Interfaces und Verträge zuerst).

### 4. Implementierung & Konvergenz (Die iterative Loop)

Dieser Schritt ersetzt den traditionellen, fehleranfälligen "Big Bang" Pull Request.

- **`Run /speckit.implement`**: Der Agent bearbeitet exakt den nächsten anstehenden Task. Er ändert den Code in der entsprechenden Komponente, fügt Tests hinzu und präsentiert das Artefakt-Diff.
- **Review:** Du prüfst als Entwickler den Code-Diff dieses Einzelschritts.
- **`Run /speckit.converge`**: Der Agent analysiert den aktuellen Stand des Codes gegen die `specs/` und `.sdd`-Regeln. Fehlt noch etwas (z. B. Error-Handling)? Dann generiert er neue Tasks, die der Liste hinzugefügt werden.
- **Repeat:** Wiederhole `/speckit.implement` und `/speckit.converge`, bis alle Tasks abgearbeitet und das Feature vollständig und robust ist.

### 5. Qualitätssicherung & Abschluss

- **Changelog:** Im letzten Task der Implementierungs-Phase (oder in der finalen Converge-Loop) sorgt der Agent dafür, dass die `CHANGELOG.md` der betroffenen Komponenten aktualisiert wird.
- **Push & PR:** Sobald die Converge-Loop erfolgreich ist, pusht der Agent (oder du) den Feature-Branch in das jeweilige GitHub-Repo und eröffnet dort den entsprechenden Pull Request (PR).
- CI/CD-Pipelines prüfen abschließend die übergreifenden Integrationstests des PRs.
- Sind alle Reviewer zufrieden, werden die Änderungen in die Hauptbranches (`main`) gemerged.

---

## 🛠️ Beispiele aus der Praxis

### Beispiel 1: Einen neuen Kafka-Collector hinzufügen

Du möchtest, dass `mitm-2` Daten aus einem Kafka-Topic liest und verschlüsselt.

1. **Plan & Specify:** Du nutzt `/speckit.specify` für `feature_kafka_collector`. Der `/speckit.plan` erkennt durch `mitm-2.sdd` sofort: "PII muss per AES-GCM verschlüsselt werden. Master Key via IPC."
2. **Tasks:** `/speckit.tasks` zerlegt dies: Task 1 (Kafka Reader bauen in `collector-layer/mitm_collector_kafka`), Task 2 (IPC Encryption im Collector einbinden).
3. **Implement:** Der Agent baut Schritt für Schritt den Code in den richtigen Repos, ohne aus Versehen Hardcoded-Keys einzubauen, da die Tasks ihn an die Spec binden.

### Beispiel 2: Ein neues JSON-Mapping (Schichtübergreifend)

Du sollst neue Felder aus einem CSV-Upload verarbeiten.

1. **Tasks:** `/speckit.tasks` generiert: Task 1 für `collector-layer/mitm_collector_csv-xls` (Datenfelder einlesen), Task 2 für `transformation-layer/mitm_transformation` (Mapping-Regeln ohne direkte Datenbankaufrufe).
2. **Converge:** Wenn der Agent bei der Implementierung von Task 1 das Output-Format anpasst, erkennt `/speckit.converge` sofort, dass Task 2 entsprechend aktualisiert werden muss. Die Architektur bleibt über Repo-Grenzen hinweg konsistent.

---

Mit diesem Flow-Forward Ansatz bleibt das `mitm-2` System auch bei komplexen, schichtübergreifenden Features immer wartbar, sicher und architektonisch sauber!
