# Acceptance scenarios

(Use EARS — `WHEN <event> THE SYSTEM SHALL <behaviour>` — or
GIVEN/WHEN/THEN. Both grammars disqualify weasel words by leaving
nowhere to put them.)

## Scenario 1: <name>

GIVEN <setup>
WHEN <action>
THEN <observable outcome>

## Scenario 2: <name>

GIVEN …
WHEN …
THEN …

## Cross-cutting checks

- After Inc <N>, manually walk <flow> and confirm <observable>.
- Rollback from Inc <N> returns the DB to pre-migration state.
- <other end-to-end check>
