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
prompt, timeout and optional generation settings. Provider responses contain
text, optional token counts and duration. No real local or remote provider is
included yet; future adapters can implement the same interface without
changing prompt or analysis components.
