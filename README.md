# Arca

ARCA is an LLM-based Swift code-issue detection tool for experiments comparing
a baseline prompt with a guided prompt containing explicit rules and supporting
knowledge.

## Build

```sh
swift build
swift run arca --help
```

## Configure the model

Create `.arca.json` in the repository root:

```json
{
  "schemaVersion": 1,
  "llm": {
    "providerID": "lm-studio",
    "baseURL": "http://127.0.0.1:1234",
    "completionPath": "/v1/chat/completions",
    "modelID": "qwen2.5-coder-7b-instruct",
    "timeoutSeconds": 120,
    "temperature": 0,
    "seed": 42
  }
}
```

The configured server must expose an OpenAI-compatible chat-completions API.
Set `ARCA_LLM_API_KEY` when authentication is required.

## Run an experiment

Choose one prompt variant for each run:

```sh
swift run arca llm \
  --file Sources/Feature.swift \
  --prompt baseline \
  --format json

swift run arca llm \
  --file Sources/Feature.swift \
  --review swift \
  --prompt guided \
  --format json
```

The baseline command does not accept `--review`. Guided review values are
`swift`, `swiftui`, `tca`, `security`, `god-object`, and `all`. Guided `all`
runs each rule set independently and aggregates its findings and measurements.

Omit `--format json` for a human-readable terminal report. JSON output uses
schema version `1` and records the prompt variant, provider, model, generation
parameters, duration, token usage, findings, and diagnostics.

## Prompt variants

- `baseline` sends the complete selected source file with broad code-issue
  detection instructions. It does not include rule IDs, rule definitions, or
  supporting knowledge and therefore does not require a review type.
- `guided` selects rules by review type from
  `Sources/ArcaKnowledge/Resources/arca-rulesets.json`. For every selected
  rule, it includes the structured rule definition and the referenced Markdown
  file from `Sources/ArcaKnowledge/Resources/References`. The model first
  checks each rule for applicability to the visible source. Irrelevant TCA or
  SwiftUI rules produce no findings, and a framework import alone is not
  treated as a violation.

Both variants use a compact response schema. The model returns an explanation
and evidence line numbers, plus a title for baseline analysis or a supplied rule
ID for guided analysis. It does not classify severity or repeat source text and
file metadata.

ARCA supplies the file path, derives each finding's range from its evidence, and
extracts the exact evidence excerpt from the source. In guided runs, ARCA also
adds the canonical title, category, and issue type from its rule registry. The
parser rejects unknown rule IDs and unsupported response fields.

## Exit statuses

| Status | Meaning |
| ---: | --- |
| `0` | Analysis completed without findings. |
| `1` | Analysis completed with findings. |
| `2` | Invalid input or configuration. |
| `3` | Provider, parser, or internal execution failure. |
