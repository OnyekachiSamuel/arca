#!/bin/zsh

# Run one experiment batch for either the first or remaining file group.
# The first group contains 6 files x 2 versions = 12 requests.
# The remaining group contains 5 files x 2 versions = 10 requests.
#
# Usage:
#   ./run-experiment-batch.sh baseline 1
#   ./run-experiment-batch.sh guided 1
#   ./run-experiment-batch.sh baseline 2
#   ./run-experiment-batch.sh guided 2
#   ./run-experiment-batch.sh baseline 1 remaining
#   ./run-experiment-batch.sh guided 1 remaining
#   ./run-experiment-batch.sh baseline 2 remaining
#   ./run-experiment-batch.sh guided 2 remaining
# The repetition number selects the run-1 or run-2 result directory. ARCA
# first writes the report to its configured output directory; this script then
# moves that exact report into the explicitly selected experiment directory
# under the selected prompt, version, and repetition directory.
#
# ARCA exits with 0 when no findings are produced and 1 when findings are
# produced. Both are successful experiment outcomes. Exit code 2 stops the
# batch because it indicates invalid input or configuration. Exit code 3 is a
# provider/parser execution failure: its diagnostic report is archived outside
# the experiment run folders and the batch continues with the next request.
#
set -u

ARCA_PROJECT="${0:A:h}"
ARCA_BIN="${ARCA_PROJECT}/.build/arm64-apple-macosx/release/arca"
DATASET_ROOT="${ARCA_PROJECT}/arca-dataset"
RESULTS_ROOT="${ARCA_PROJECT}/arca-results/gpt-6.1-sol-run"
PROVIDER_ID="openai-sol"

PROMPT_VARIANT="${1:-}"
REPETITION="${2:-}"
DATASET_GROUP="${3:-first}"
SCRIPT_NAME="${0:t}"

usage() {
  print -r -u2 -- "Usage: ${SCRIPT_NAME} <baseline|guided> <1|2> [first|remaining]"
}

if [[ "${PROMPT_VARIANT}" != "baseline" && "${PROMPT_VARIANT}" != "guided" ]]; then
  usage
  exit 2
fi

if [[ "${REPETITION}" != "1" && "${REPETITION}" != "2" ]]; then
  usage
  exit 2
fi

if [[ ! -x "${ARCA_BIN}" ]]; then
  print -r -u2 -- "Release executable does not exist: ${ARCA_BIN}"
  print -r -u2 -- "Build it once with: swift build -c release"
  exit 2
fi

if [[ "${PROVIDER_ID}" == "openai-sol" && -z "${OPENAI_API_KEY:-}" ]]; then
  print -r -u2 -- "OPENAI_API_KEY is not set for the openai-sol provider."
  exit 2
fi

if [[ "${DATASET_GROUP}" == "first" ]]; then
  FILES=(
    "Analytics.swift"
    "BrazeService.swift"
    "EcosiaAuthenticationService.swift"
    "EcosiaAuthUIStateProvider.swift"
    "EcosiaBrowserWindowAuthManager.swift"
    "FinancialReports.swift"
  )
elif [[ "${DATASET_GROUP}" == "remaining" ]]; then
  FILES=(
    "Statistics.swift"
    "News.swift"
    "Images.swift"
    "InvestmentsProjection.swift"
    "TreesProjection.swift"
  )
else
  usage
  exit 2
fi

REQUEST_COUNT=$((${#FILES} * 2))
FAILED_RUNS=0

for file in "${FILES[@]}"; do
  for version in pre-fix post-fix; do
    source_path="${DATASET_ROOT}/${version}/${file}"
    if [[ ! -f "${source_path}" ]]; then
      print -r -u2 -- "Dataset file does not exist: ${source_path}"
      exit 2
    fi
  done
done

run_arca() {
  local target_directory="$1"
  local analysis_directory="$2"
  local version="$3"
  shift 3
  local output
  local exit_code
  local report_path
  local report_name
  local destination
  local capture_file
  local failed_directory
  local failed_destination

  capture_file="$(mktemp -t arca-experiment.XXXXXX)" || exit 2
  command "${ARCA_BIN}" "$@" 2>&1 | tee "${capture_file}"
  exit_code=${pipestatus[1]}
  output="$(<"${capture_file}")"
  rm -f "${capture_file}"

  report_path="$(
    printf '%s\n' "${output}" \
      | sed -n 's/^JSON report written to: //p' \
      | tail -n 1
  )"

  if (( exit_code == 3 )); then
    FAILED_RUNS=$((FAILED_RUNS + 1))

    if [[ -n "${report_path}" && -f "${report_path}" ]]; then
      report_name="${report_path:t}"
      failed_directory="${RESULTS_ROOT}/failed-runs/${analysis_directory}/${version}/run-${REPETITION}"
      failed_destination="${failed_directory}/${report_name}"
      mkdir -p "${failed_directory}" || exit 2

      if [[ -e "${failed_destination}" ]]; then
        print -r -u2 -- "Refusing to overwrite the existing failed-run report: ${failed_destination}"
        exit 2
      fi

      mv "${report_path}" "${failed_destination}" || exit 2
      print -r -u2 -- "Analysis failed; diagnostic report archived at: ${failed_destination}"
    else
      print -r -u2 -- "Analysis failed with exit code 3 and produced no diagnostic report."
    fi

    return 0
  fi

  if (( exit_code >= 2 )); then
    print -r -u2 -- "ARCA stopped with exit code ${exit_code}. Fix the input or configuration, then restart this batch."
    exit "${exit_code}"
  fi

  if [[ -z "${report_path}" || ! -f "${report_path}" ]]; then
    print -r -u2 -- "ARCA completed but the generated JSON report path could not be located."
    exit 2
  fi

  report_name="${report_path:t}"
  destination="${target_directory}/${report_name}"

  mkdir -p "${target_directory}" || exit 2

  if [[ -e "${destination}" ]]; then
    print -r -u2 -- "Refusing to overwrite the existing report: ${destination}"
    exit 2
  fi

  mv "${report_path}" "${destination}" || exit 2
  print -r -- "Experiment report stored at: ${destination}"
}

run_version() {
  local file="$1"
  local version="$2"
  local source_name="${file:r}"
  local analysis_directory
  local destination_directory
  local -a existing_reports

  print -r -- ""
  print -r -- "--- ${PROMPT_VARIANT}, repetition ${REPETITION}: ${file}, ${version} ---"

  if [[ "${PROMPT_VARIANT}" == "baseline" ]]; then
    analysis_directory="baseline"
    destination_directory="${RESULTS_ROOT}/${analysis_directory}/${version}/run-${REPETITION}"
    existing_reports=("${destination_directory}/${source_name}-"*.json(N))
  else
    analysis_directory="guided-analysis"
    destination_directory="${RESULTS_ROOT}/${analysis_directory}/${version}/run-${REPETITION}"
    existing_reports=("${destination_directory}/${source_name}-swift-"*.json(N))
  fi

  if (( ${#existing_reports} > 0 )); then
    print -r -- "Skipping: an experiment report already exists for this combination:"
    print -r -- "${existing_reports[1]}"
    return 0
  fi

  if [[ "${PROMPT_VARIANT}" == "baseline" ]]; then
    run_arca "${destination_directory}" "${analysis_directory}" "${version}" \
      --file "${DATASET_ROOT}/${version}/${file}" \
      --prompt baseline \
      --provider "${PROVIDER_ID}" \
      --format json
  else
    run_arca "${destination_directory}" "${analysis_directory}" "${version}" \
      --file "${DATASET_ROOT}/${version}/${file}" \
      --prompt guided \
      --review swift \
      --provider "${PROVIDER_ID}" \
      --format json
  fi
}

cd "${ARCA_PROJECT}" || exit 2

print -r -- "========== GPT-6.1-SOL — ${(U)PROMPT_VARIANT} — ${(U)DATASET_GROUP} FILES — REPETITION ${REPETITION} =========="
print -r -- "Provider: ${PROVIDER_ID}"
print -r -- "Results root: ${RESULTS_ROOT}"

for file in "${FILES[@]}"; do
  run_version "${file}" "pre-fix"
  run_version "${file}" "post-fix"
done

print -r -- ""
if (( FAILED_RUNS > 0 )); then
  print -r -u2 -- "Batch finished with ${FAILED_RUNS} failed request(s). Rerun this command after restoring the LLM provider; completed combinations will be skipped."
  exit 3
fi

print -r -- "Completed ${PROMPT_VARIANT} ${DATASET_GROUP}-files repetition ${REPETITION}: ${REQUEST_COUNT} valid ARCA reports are present."
