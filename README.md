# arcan

Code review tool for anti-patterns and team convention rule violation detection with fix suggestions.

## Build and run

```sh
swift build
.build/debug/arcan review --help
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

## LLM provider boundary

`ArcanLLM` defines a provider-independent asynchronous interface with model,
prompt, timeout and optional generation settings. `LLMServerProvider` connects
to a local or remote HTTP server that accepts chat-completion requests.

LLM suggestions are disabled when `.arcan.json` has no `llm` block. Adding
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
swift run arcan review \
  --file Sources/Example/LargeCoordinator.swift \
  --review god-object
```

The God Object is still detected deterministically. When generation succeeds,
its generic guidance is replaced with validated, targeted steps and an
optional illustrative Swift code example. If the provider or response fails,
the deterministic suggestion remains and the report contains a warning.

For an authenticated remote server, provide the secret through
`ARCAN_LLM_API_KEY`; do not store it in `.arcan.json`.
