# Entwickler-Guide: SpecDD & GitHub Spec Kit

Willkommen im `mitm-2` Projekt! Wir nutzen eine Kombination aus **SpecDD** (Architektur-Wahrheit) und **GitHub Spec Kit** (Feature-Entwicklung), um das System robust zu halten und gleichzeitig schnell neue Funktionen zu bauen.
Dieser Guide erklärt dir, wie du als Entwickler oder KI-Agent damit im Alltag arbeitest.

## Warum zwei Frameworks?

- **SpecDD (`.sdd` Dateien):** Ist das "Grundgesetz" des Projekts. Es definiert Architektur-Schichten, harte Security-Vorgaben (wie Verschlüsselung) und Modulgrenzen. Es ändert sich selten.
- **GitHub Spec Kit (Markdown-Features):** Ist der "Arbeitsauftrag". Wenn du etwas Neues bauen willst (z.B. einen API-Endpunkt), schreibst du ein Spec Kit Dokument. Es ändert sich schnell und ist iterativ.

## Der alltägliche Workflow in 3 Schritten

### 1. Rahmenbedingungen checken (SpecDD lesen)

Bevor du ein Feature planst, schau in die `.sdd` Dateien in deinem Zielordner (z.B. `mitm-2.sdd`). Sie verraten dir, was du tun **darfst** und was absolut **verboten** ist (z.B. `Must not` oder `Forbids`).

### 2. Feature planen (Spec Kit schreiben)

Du hast zwei Möglichkeiten, ein Feature zu planen:

**Option A: Über GitHub Issues (Empfohlen)**
Gehe im GitHub-Repository auf **Issues -> New Issue** und wähle das Template **"Feature Specification (Spec Kit)"**. GitHub füllt die Vorlage automatisch für dich aus. Fülle die Felder aus und bestätige über die Checkboxen, dass dein Feature die SpecDD-Regeln (Drift-Kontrolle) nicht bricht.

**Option B: Als Markdown-Datei im Projekt**
Kopiere die Vorlage `.github/spec-kit/feature_template.md` in einen neuen Ordner `docs/features/` (z. B. `docs/features/feature_kafka_collector.md`). Beschreibe dort, was das Feature tun soll, und checke die Datei als Teil deines Feature-Branches in Git ein.

Wichtig: In beiden Wegen setzt du dich explizit mit den bestehenden SpecDD-Architekturregeln auseinander!

### 3. Implementierung (Durch KI oder Entwickler)

Das Issue oder die Markdown-Datei dient nun als verbindlicher Arbeitsauftrag.

- **KI-Agenten (z. B. Antigravity oder Copilot):** Lesen das Spec Kit, prüfen selbstständig die verlinkten SpecDD-Architekturvorgaben (`.sdd`) und generieren den Code passgenau (inklusive SPDX-Header und Unit-Tests).
- **Menschliche Entwickler:** Setzen die spezifizierten Tasks aus dem Spec Kit Schritt für Schritt in einem eigenen Git-Branch (`feature/...`) um.

### 4. Qualitätssicherung (QA) & Code Review

Sobald der Code fertig ist, wird ein Pull Request (PR) erstellt, der das GitHub Issue verlinkt (z. B. durch `Closes #42`).
In dieser Phase wird geprüft:

- Erfüllt der Code alle "Acceptance Criteria" aus dem Spec Kit?
- Werden die CI/CD-Pipelines grün?
- Wurde wirklich keine SpecDD-Regel verletzt (z. B. Envelope Encryption umgangen)?

### 5. Abnahme & Abschluss

Sind alle Reviewer und Architektur-Hüter zufrieden, wird der Pull Request in den `main`-Branch gemerged.
Durch das Schlüsselwort im PR wird das Spec Kit GitHub Issue automatisch **geschlossen**. Das Feature ist damit erfolgreich entwickelt, in der Architektur verankert und live!

---

## 🛠️ Beispiele aus der Praxis

### Beispiel 1: Einen neuen Kafka-Collector hinzufügen

Du möchtest, dass `mitm-2` Daten aus einem Kafka-Topic liest.

- **Was sagt SpecDD?**
  Die Root-Spec (`mitm-2.sdd`) sagt: "Alle PII Daten müssen sofort per AES-GCM verschlüsselt werden. Der Master Key kommt per IPC-Socket."
- **Wie sieht dein Spec Kit aus?**
  Du schreibst ein Dokument `feature_kafka_collector.md`. Darin steht: "Der Collector liest Topic X. Für die PII-Felder `email` und `ssn` fordert er den KEK via IPC an und verschlüsselt sie."
- **Ergebnis:** Das Feature passt perfekt in die Architektur. Niemand hat aus Versehen einen Hardcoded-Key benutzt.

### Beispiel 2: Ein neues JSON-Mapping für die Transformation-Layer

Du sollst neue Felder aus einem CSV-Upload in das interne JSON-Format mappen.

- **Was sagt SpecDD?**
  Die Spec sagt: "Die Transformation-Layer ist zustandslos und darf nicht direkt in die Datenbank schreiben."
- **Wie sieht dein Spec Kit aus?**
  Du schreibst `feature_employee_mapping_v2.md`. Darin beschreibst du die Mapping-Logik.
- **Ergebnis:** Der Entwickler / KI-Agent baut nur reine Go-Funktionen ohne Datenbank-Importe. Die Architektur bleibt sauber.

---

Mit diesem Ansatz bleibt das `mitm-2` System auch bei vielen neuen Features immer wartbar, sicher und architektonisch sauber!
