# Arca

Code review tool for anti-patterns and team convention rule violation detection with fix suggestions.

## Build and run

```sh
swift build
.build/debug/arca review --help
```

## Exit statuses

| Status | Meaning |
| ---: | --- |
| `0` | Review completed without findings. |
| `1` | Review completed with findings. |
| `2` | Invalid input or configuration. |
| `3` | Analyzer or internal execution failure. |

Completed reports are written to standard output for both status `0` and
status `1`. Errors are written to standard error.

## Normalized findings

JSON reports use schema version `5`. Findings inside a discovered Git
repository use repository-relative paths; explicit files outside it retain
canonical absolute paths. Source ranges are one-based and inclusive.

Each finding has a canonical category and severity. Analyzer-specific input is
retained in the finding's typed `metadata`, such as SwiftLint's original rule,
severity and location or the God Object analyzer's structural metrics.

The `sources` array records stable analyzer identifiers such as `god-object`
and `swiftlint`. An array is used so a future merged finding can retain every
analyzer that detected it while keeping deterministic JSON order.

## Complete-file LLM analysis context

LLM source analysis is prepared one selected Swift file at a time. An explicit
file contributes only that file, while changed-file review contributes one
independent context for each selected current file together with its added,
modified and deleted line ranges. ARCA does not scan or include the whole
repository automatically.

Source content is preserved without truncation or rewriting. The default
complete-file limit is 64,000 UTF-8 bytes. A file above that limit is skipped
for LLM analysis with an explicit warning, while smaller selected files and
static analyzers can continue. The complete-file limit and the later total
prompt limit are separate controls.

## LLM provider boundary

`ArcaLLM` defines a provider-independent asynchronous interface with model,
prompt, timeout and optional generation settings. `LLMServerProvider` connects
to a local or remote HTTP server that accepts chat-completion requests.

LLM suggestions are disabled when `.arca.json` has no `llm` block. Adding
the block enables hybrid enrichment:

```json
{
  "schemaVersion": 1,
  "llm": {
    "providerID": "local-qwen",
    "baseURL": "http://127.0.0.1:8080",
    "completionPath": "/v1/chat/completions",
    "modelID": "qwen2.5-coder",
    "timeoutSeconds": 120,
    "temperature": 0.2,
    "seed": 42
  }
}
```

Start the configured model server, then review a known God Object:

```sh
swift run arca review \
  --file Sources/Example/LargeCoordinator.swift \
  --review god-object
```

## Isolated LLM prompt experiments

Use `arca llm` to run LLM detection by itself. The command does not run
static analyzers, aggregate findings, categorize findings, or compare runs.
Choose and record one prompt variant per invocation:

```sh
swift run arca llm \
  --file Sources/Example/LargeCoordinator.swift \
  --review god-object \
  --prompt baseline \
  --format json

swift run arca llm \
  --file Sources/Example/LargeCoordinator.swift \
  --review god-object \
  --prompt guided \
  --format json
```

`baseline` uses its own prompt template containing the source and broad
instructions to detect code smells and anti-patterns. The selected review is
recorded as experiment metadata, but its name, canonical rule ID, and knowledge
are not sent to the model. Baseline findings therefore preserve the model's own
issue title and type and do not claim an ARCA rule ID. `guided` uses a separate
prompt template containing the selected rule knowledge and retains canonical
rule IDs. Omit `--format json` for a human-readable terminal report. JSON records
the prompt variant, template identity and version, provider, model, generation
settings, usage, duration, findings, and diagnostics for that run.
If an evidence excerpt does not exactly match its declared source lines, the
tool retains the finding and records a warning. Isolated runs keep it for
human evaluation, while normal reviews also pass it into aggregation and
categorization. Malformed responses and structurally unusable findings remain
validation failures.

The God Object is still detected deterministically. When generation succeeds,
its generic guidance is replaced with validated, targeted steps and an
optional illustrative Swift code example. If the provider or response fails,
the deterministic suggestion remains and the report contains a warning.

For an authenticated remote server, provide the secret through
`ARCA_LLM_API_KEY`; do not store it in `.arca.json`.
