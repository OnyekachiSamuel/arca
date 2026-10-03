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
    "defaultProvider": "local",
    "providers": [
      {
        "id": "local",
        "baseURL": "http://127.0.0.1:1234",
        "completionPath": "/v1/chat/completions",
        "modelID": "qwen2.5-coder-7b-instruct",
        "timeoutSeconds": 120,
        "temperature": 0,
        "seed": 42
      },
      {
        "id": "openai",
        "baseURL": "https://api.openai.com",
        "completionPath": "/v1/chat/completions",
        "modelID": "YOUR_OPENAI_MODEL_ID",
        "apiKeyEnvironmentVariable": "OPENAI_API_KEY",
        "timeoutSeconds": 120,
        "temperature": 0,
        "seed": 42
      }
    ]
  }
}
```

Each configured server must expose an OpenAI-compatible chat-completions API.
The `defaultProvider` is used when `--provider` is omitted. Replace
`YOUR_OPENAI_MODEL_ID` with a model available to your OpenAI project.

For authenticated providers, `apiKeyEnvironmentVariable` contains the name
of the environment variable—not the secret itself. Export that variable before
running ARCA:

```sh
export OPENAI_API_KEY="your-api-key"
```

ARCA reads the value at runtime and sends it as a bearer token. It does not
store the value in `.arca.json` or include it in reports and diagnostics.

## Run an experiment

Choose one prompt variant for each run:

```sh
swift run arca \
  --file Sources/Feature.swift \
  --prompt baseline \
  --format json

swift run arca \
  --file Sources/Feature.swift \
  --review swift \
  --prompt guided \
  --provider openai \
  --format json
```

Use `--provider local` for LM Studio, `--provider openai` for OpenAI, or
omit the option to use `llm.defaultProvider`.

Add `--show-prompt` to display the exact prompt sent to the configured LLM.
ARCA still completes the analysis and presents or writes the requested report.
Guided `all` displays each independently submitted prompt. Without this option,
the existing output is unchanged.

The baseline command does not accept `--review`. Guided review values are
`swift`, `swiftui`, `tca`, `security`, `god-object`, and `all`. Guided `all`
runs each rule set independently and aggregates its findings and measurements.

Omit `--format json` for a human-readable terminal report. With
`--format json`, ARCA writes a new schema-versioned report under
`arca-results/baseline` or `arca-results/guided-analysis` and prints its path.
Guided filenames include the selected review type. Each report records the
prompt variant, provider, model, generation parameters, duration, token usage,
findings, and diagnostics.

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
adds the canonical title from its rule registry. Category remains catalogue
metadata and is not included in prompts or finding reports. The parser rejects
unknown rule IDs and unsupported response fields.

When the selected file has uncommitted Git changes, ARCA includes its added,
modified, and deleted ranges as optional attention signals. When no matching
change exists, the change field is omitted. The complete current source is sent
in both cases.

## Exit statuses

| Status | Meaning |
| ---: | --- |
| `0` | Analysis completed without findings. |
| `1` | Analysis completed with findings. |
| `2` | Invalid input or configuration. |
| `3` | Provider, parser, or internal execution failure. |
