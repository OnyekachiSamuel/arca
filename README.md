# ARCA

ARCA is a research-oriented command-line tool for LLM-based review of Swift
source code. It supports controlled experiments comparing a general baseline
prompt with a knowledge-guided prompt containing explicit review rules and
supporting references.

ARCA analyses one Swift file per request. It normalizes model output into a
common finding format, validates rule identifiers and source locations, and
records execution metadata for later evaluation.

## Analysis modes

| Mode | Input supplied to the model |
| --- | --- |
| `baseline` | Complete source file and general code-review instructions. No ARCA rules are included. |
| `guided` | Complete source file, the selected ARCA rules, and their supporting knowledge. |

Guided analysis supports these review types:

- `swift`
- `swiftui`
- `tca`
- `security`
- `god-object`
- `all`

The `all` option evaluates each rule set independently and aggregates the
results. Baseline analysis does not accept a review type.

## Requirements

- macOS 13 or later
- Swift 6.2 or later
- an OpenAI-compatible `/v1/chat/completions` endpoint that supports structured
  JSON responses

The endpoint can be a local server such as LM Studio or an authenticated cloud
provider.

## Build and test

```bash
swift build
swift test
swift run arca --help
```

For repeated experiments, build the executable once in release mode:

```bash
swift build -c release
```

## Configuration

Create `.arca.json` in the repository root. The following example configures a
local provider and an authenticated cloud provider:

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
        "modelID": "<local-model-id>",
        "timeoutSeconds": 600,
        "temperature": 0.7,
        "seed": 42
      },
      {
        "id": "cloud",
        "baseURL": "https://api.openai.com",
        "completionPath": "/v1/chat/completions",
        "modelID": "<cloud-model-id>",
        "apiKeyEnvironmentVariable": "OPENAI_API_KEY",
        "timeoutSeconds": 600
      }
    ]
  }
}
```

The configured model ID must match the identifier exposed by the selected
provider.

For authenticated providers, store only the environment-variable name in the
configuration and export the secret before running ARCA:

```bash
export OPENAI_API_KEY="<API key>"
```

ARCA reads the secret at runtime and does not include it in reports or
diagnostics.

## Run an analysis

Baseline analysis:

```bash
swift run arca \
  --file Sources/Feature.swift \
  --prompt baseline \
  --provider local \
  --format json
```

Knowledge-guided Swift analysis:

```bash
swift run arca \
  --file Sources/Feature.swift \
  --prompt guided \
  --review swift \
  --provider cloud \
  --format json
```

`--provider` selects a configured provider ID. When it is omitted, ARCA uses
`llm.defaultProvider`. Add `--show-prompt` to print the exact prompt sent to the
model.

The default output is a human-readable terminal report. With `--format json`,
ARCA writes a schema-versioned report under:

```text
arca-results/baseline/
arca-results/guided-analysis/
```

Reports contain the normalized findings, diagnostics, provider and model IDs,
generation parameters, duration, request count, and token usage.

## Processing pipeline

For each request, ARCA:

1. loads and validates the selected Swift file;
2. records relevant uncommitted Git line ranges when available;
3. builds either the baseline or guided prompt;
4. requests a structured response from the configured model;
5. validates rule references, evidence, and one-based source ranges;
6. normalizes valid candidates into a common report; and
7. renders the result in terminal or JSON format.

Changed lines are attention signals only. Both analysis modes receive the
complete current source file.

## Exit statuses

| Status | Meaning |
| ---: | --- |
| `0` | Analysis completed without findings. |
| `1` | Analysis completed with findings. |
| `2` | Invalid input or configuration. |
| `3` | Provider, response-parser, or internal execution failure. |

Statuses `0` and `1` both represent successful analyses.

## Rules and provenance

Guided rules are defined in
[`Sources/ArcaKnowledge/Resources/arca-rulesets.json`](Sources/ArcaKnowledge/Resources/arca-rulesets.json),
with supporting Markdown under
[`Sources/ArcaKnowledge/Resources/References`](Sources/ArcaKnowledge/Resources/References).

The provenance of the Swift concurrency rules is documented in
[`Docs/SwiftConcurrencyRuleSources.md`](Docs/SwiftConcurrencyRuleSources.md).
Third-party attribution and licensing are provided in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Experiment materials

- [`arca-dataset`](arca-dataset) contains the pre-fix and post-fix benchmark
  files.
- [`experiment-run-sequence.md`](experiment-run-sequence.md) documents the
  reproducible 88-request batch protocol.
- [`run-experiment-batch.sh`](run-experiment-batch.sh) runs and organizes the
  experiment batches.
- [`Outputs/Ground-truth`](Outputs/Ground-truth) contains the benchmark ground
  truth.
- [`Outputs/Evaluation`](Outputs/Evaluation) contains the completed evaluation
  spreadsheets.

## Scope and limitations

ARCA is an experimental detection tool, not a replacement for the Swift
compiler, static analysis, or human review.

The current implementation is limited to single-file analysis. It does not
resolve declarations or execution behavior across files, modules, or an entire
repository. Consequently, guided rules are designed to require evidence that
is visible within the analysed file.

## License

ARCA is distributed under the terms in [`LICENSE`](LICENSE).
