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
