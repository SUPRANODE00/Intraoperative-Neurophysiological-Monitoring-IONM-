#!/usr/bin/env bash

set -euo pipefail

REPO="${GITHUB_REPOSITORY:-SUPRANODE00/Intraoperative-Neurophysiological-Monitoring-IONM-}"
JSON_FILE="${1:-audit_batch_02.json}"
THRESHOLD_MINS="${THRESHOLD_MINS:-15}"

if [[ ! -f "$JSON_FILE" ]]; then
  echo "Error: File '$JSON_FILE' not found." >&2
  exit 1
fi

echo "==> Parsing audit payload: $JSON_FILE..."

extract_field() {
  local key="$1"
  awk -v key="$key" '
    BEGIN { FS=":"; val="" }
    $0 ~ "\"" key "\"" {
      val = $0
      sub(/^[^:]*:/, "", val)
      gsub(/^[ \t\r\n"]+|[ \t\r\n",]+$/, "", val)
      print val
      exit
    }
  ' "$JSON_FILE"
}

CPT_CODE=$(extract_field "cpt_code")
SESSION_ID=$(extract_field "session_id")
DURATION_REC=$(extract_field "telemetry_duration_minutes")
UNITS_REC=$(extract_field "recorded_units")
UNITS_BILLED=$(extract_field "billed_units")
DELTA_MINS=$(extract_field "delta_minutes")
DSP_WARN=$(extract_field "dsp_warning")

DELTA_MINS="${DELTA_MINS:-0}"
UNITS_REC="${UNITS_REC:-0}"
UNITS_BILLED="${UNITS_BILLED:-0}"

ABS_DELTA=$(awk -v d="$DELTA_MINS" 'BEGIN { print (d < 0 ? -d : d) }')

echo "------------------------------------------------"
echo "CPT Code:        $CPT_CODE"
echo "Session ID:      $SESSION_ID"
echo "Duration (Min):  $DURATION_REC"
echo "Recorded Units:  $UNITS_REC"
echo "Billed Units:    $UNITS_BILLED"
echo "Delta Minutes:   $DELTA_MINS (Abs: $ABS_DELTA, Threshold: $THRESHOLD_MINS)"
echo "DSP Warning:     ${DSP_WARN:-None}"
echo "------------------------------------------------"

HAS_UNIT_DISCREPANCY=0
if [[ "$UNITS_REC" != "$UNITS_BILLED" ]]; then
  HAS_UNIT_DISCREPANCY=1
fi

if [[ "$ABS_DELTA" -lt "$THRESHOLD_MINS" ]] && [[ "$HAS_UNIT_DISCREPANCY" -eq 0 ]]; then
  echo "==> Audit Passed: Delta ($ABS_DELTA mins) is within tolerance (< $THRESHOLD_MINS mins) and units match."
  exit 0
fi

echo "==> Audit Discrepancy Detected! Delta exceeds threshold or unit mismatch found. Processing issue..."

REQUIRED_LABELS=("cpt-audit" "discrepancy" "telemetry")
REQUIRED_COLORS=("0E8A16" "B60205" "1D76DB")
REQUIRED_DESCS=("CPT Telemetry Automated Audits" "Billing or Telemetry Discrepancy" "IONM Telemetry Stream Alert")

ensure_labels_exist() {
  echo "==> Verifying repository labels on $REPO..."
  EXISTING_LABELS=$(gh api "repos/$REPO/labels" --paginate --jq '.[].name' 2>/dev/null || true)

  for i in "${!REQUIRED_LABELS[@]}"; do
    LABEL="${REQUIRED_LABELS[$i]}"
    COLOR="${REQUIRED_COLORS[$i]}"
    DESC="${REQUIRED_DESCS[$i]}"

    if echo "$EXISTING_LABELS" | grep -qx "$LABEL"; then
      echo "  [✓] Label '$LABEL' exists."
    else
      echo "  [+] Creating missing label '$LABEL'..."
      gh api --method POST "repos/$REPO/labels" \
        -f name="$LABEL" \
        -f color="$COLOR" \
        -f description="$DESC" >/dev/null
    fi
  done
}

ensure_labels_exist

ISSUE_TITLE="[Audit Alert] Discrepancy in CPT $CPT_CODE (Session: $SESSION_ID)"

ISSUE_BODY=$(cat <<EOT
## 🚨 CPT Telemetry Audit Discrepancy Alert

A telemetry disparity was detected during automated payload verification.

### Metric Details
* **CPT Code:** \`$CPT_CODE\`
* **Session ID:** \`$SESSION_ID\`
* **Telemetry Duration:** \`$DURATION_REC\` minutes
* **Delta Minutes:** \`$DELTA_MINS\` *(Threshold: ${THRESHOLD_MINS}m)*
* **Recorded Units:** \`$UNITS_REC\`
* **Billed Units:** \`$UNITS_BILLED\`
* **DSP Warning:** \`${DSP_WARN:-None}\`

### Audit Findings
$(if [[ "$ABS_DELTA" -ge "$THRESHOLD_MINS" ]]; then echo "* ⚠️ **Duration Variance Exceeded:** Delta of \`${DELTA_MINS}m\` exceeds allowable threshold of \`${THRESHOLD_MINS}m\`."; fi)
$(if [[ "$HAS_UNIT_DISCREPANCY" -eq 1 ]]; then echo "* ⚠️ **Unit Mismatch:** Recorded units (\`${UNITS_REC}\`) do not match billed units (\`${UNITS_BILLED}\`)."; fi)

---
*Generated automatically by POSIX Telemetry Audit Pipeline.*
EOT
)

LABEL_ARGS=""
for L in "${REQUIRED_LABELS[@]}"; do
  LABEL_ARGS="$LABEL_ARGS --label $L"
done

echo "==> Submitting GitHub Issue..."
gh issue create \
  --repo "$REPO" \
  --title "$ISSUE_TITLE" \
  --body "$ISSUE_BODY" \
  $LABEL_ARGS

echo "==> Success! Issue raised successfully."
