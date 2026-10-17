# ARCA Experiment Run Sequence

This guide reproduces the experiment protocol and output layout used for the
GPT-6.1-Sol evaluation. The experiment compares baseline and guided analysis
over pre-fix and post-fix versions of 11 Swift files, with two repetitions per
combination. This produces 88 requests in total.

## Prerequisites

Run the following commands from the root of the ARCA repository:

```bash
cd /path/to/arca
swift build -c release
export OPENAI_API_KEY="<API key>"
```

Before starting, confirm that:

- `.arca.json` contains an `openai-sol` provider configuration.
- `arca-dataset/pre-fix` and `arca-dataset/post-fix` contain all 11 files.
- The model, prompts, rules, temperature, seed, and provider configuration will
  remain unchanged throughout the experiment.
- No successful reports from an earlier execution are present in the target
  run directories. Existing reports cause completed combinations to be
  skipped rather than overwritten.

The batch script resolves the repository root from its own location, so it does
not depend on a particular username or absolute checkout path.

## Dataset groups

The `first` group contains six files and produces 12 requests per batch:

- `Analytics.swift`
- `BrazeService.swift`
- `EcosiaAuthenticationService.swift`
- `EcosiaAuthUIStateProvider.swift`
- `EcosiaBrowserWindowAuthManager.swift`
- `FinancialReports.swift`

The `remaining` group contains five files and produces 10 requests per batch:

- `Statistics.swift`
- `News.swift`
- `Images.swift`
- `InvestmentsProjection.swift`
- `TreesProjection.swift`

For every file, the pre-fix request is immediately followed by its post-fix
request.

## Execution order

Run the first group in this order:

### 1. Baseline, repetition 1

```bash
./run-experiment-batch.sh baseline 1 first
```

### 2. Guided, repetition 1

```bash
./run-experiment-batch.sh guided 1 first
```

### 3. Baseline, repetition 2

```bash
./run-experiment-batch.sh baseline 2 first
```

### 4. Guided, repetition 2

```bash
./run-experiment-batch.sh guided 2 first
```

Then run the remaining group in the same order:

### 5. Baseline, repetition 1

```bash
./run-experiment-batch.sh baseline 1 remaining
```

### 6. Guided, repetition 1

```bash
./run-experiment-batch.sh guided 1 remaining
```

### 7. Baseline, repetition 2

```bash
./run-experiment-batch.sh baseline 2 remaining
```

### 8. Guided, repetition 2

```bash
./run-experiment-batch.sh guided 2 remaining
```

Allow comparable idle or cooling time between batches so that local machine
load does not vary unnecessarily. Do not alter the experimental configuration
between batches.

## Output layout

Successful reports are stored under:

```text
<repository-root>/arca-results/gpt-6.1-sol-run/
├── baseline/
│   ├── pre-fix/
│   │   ├── run-1/
│   │   └── run-2/
│   └── post-fix/
│       ├── run-1/
│       └── run-2/
└── guided-analysis/
    ├── pre-fix/
    │   ├── run-1/
    │   └── run-2/
    └── post-fix/
        ├── run-1/
        └── run-2/
```

Provider or parser failures are stored separately under:

```text
<repository-root>/arca-results/gpt-6.1-sol-run/failed-runs/
```

Exit codes `0` and `1` are both successful: `0` means no findings were
reported, while `1` means findings were reported. Exit code `2` indicates an
input or configuration error and stops the batch. Exit code `3` indicates a
provider, parser, or internal execution failure; the diagnostic report is
archived under `failed-runs`, and the batch continues.

## Completion check

A complete experiment contains:

- 44 baseline reports;
- 44 guided reports;
- 88 successful reports in total; and
- no unresolved combinations represented only under `failed-runs`.

Because LLM generation can vary, following this procedure reproduces the
experimental conditions and request sequence, but it does not guarantee
byte-identical model responses.
