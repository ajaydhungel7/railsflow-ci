#!/usr/bin/env bash
# canary-check.sh — monitors the canary deployment by polling CloudWatch ALB metrics.
#
# Works with internal ALBs — queries AWS APIs directly, no HTTP access to the ALB needed.
# Exits 0 (success) if the canary stays healthy for the full monitoring window.
# Exits 1 (failure) if error rate or latency exceeds thresholds at any point.
#
# Required env vars (set by configure-aws-credentials in the workflow):
#   AWS_REGION           — e.g. ca-central-1
#
# Required env vars (set in the canary job):
#   CANARY_RELEASE_NAME  — Helm release name of the canary (default: shopstream-canary)
#   NAMESPACE            — Kubernetes namespace (default: shopstream)
#
# Thresholds:
#   ERROR_RATE_THRESHOLD — max acceptable 5XX % of total requests (default: 5)
#   LATENCY_THRESHOLD_MS — max acceptable p99 response time in ms (default: 2000)
#   MONITOR_DURATION_S   — total monitoring window in seconds (default: 600 = 10 min)
#   POLL_INTERVAL_S      — seconds between CloudWatch polls (default: 30)

set -euo pipefail

CANARY_RELEASE_NAME="${CANARY_RELEASE_NAME:-shopstream-canary}"
NAMESPACE="${NAMESPACE:-shopstream}"
ERROR_RATE_THRESHOLD="${ERROR_RATE_THRESHOLD:-5}"
LATENCY_THRESHOLD_MS="${LATENCY_THRESHOLD_MS:-2000}"
MONITOR_DURATION_S="${MONITOR_DURATION_S:-600}"
POLL_INTERVAL_S="${POLL_INTERVAL_S:-30}"
REGION="${AWS_REGION:-ca-central-1}"

# Resolve the ALB name from the canary ingress
get_alb_name() {
  local alb_hostname
  alb_hostname=$(kubectl get ingress "$CANARY_RELEASE_NAME" \
    -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

  if [ -z "$alb_hostname" ]; then
    echo "ERROR: Could not get ALB hostname from ingress $CANARY_RELEASE_NAME" >&2
    exit 1
  fi

  # ALB hostname format: <name>-<id>.<region>.elb.amazonaws.com
  # CloudWatch dimension needs: app/<name>/<id>
  local alb_id
  alb_id=$(aws elbv2 describe-load-balancers \
    --region "$REGION" \
    --query "LoadBalancers[?DNSName=='${alb_hostname}'].LoadBalancerArn" \
    --output text)

  if [ -z "$alb_id" ]; then
    echo "ERROR: Could not find ALB ARN for hostname $alb_hostname" >&2
    exit 1
  fi

  # Extract the dimension value: app/<name>/<id>
  echo "$alb_id" | sed 's|.*:loadbalancer/||'
}

get_metric() {
  local metric_name="$1"
  local stat="$2"
  local alb_dimension="$3"
  local end_time
  local start_time
  end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  start_time=$(date -u -d "-${POLL_INTERVAL_S} seconds" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u -v "-${POLL_INTERVAL_S}S" +"%Y-%m-%dT%H:%M:%SZ")  # macOS fallback

  aws cloudwatch get-metric-statistics \
    --region "$REGION" \
    --namespace "AWS/ApplicationELB" \
    --metric-name "$metric_name" \
    --dimensions "Name=LoadBalancer,Value=${alb_dimension}" \
    --start-time "$start_time" \
    --end-time "$end_time" \
    --period "$POLL_INTERVAL_S" \
    --statistics "$stat" \
    --query "Datapoints[0].${stat}" \
    --output text 2>/dev/null || echo "0"
}

echo "=== Canary Monitor Started ==="
echo "Release:    $CANARY_RELEASE_NAME"
echo "Window:     ${MONITOR_DURATION_S}s (polling every ${POLL_INTERVAL_S}s)"
echo "Thresholds: 5XX < ${ERROR_RATE_THRESHOLD}% | p99 latency < ${LATENCY_THRESHOLD_MS}ms"
echo ""

ALB_DIMENSION=$(get_alb_name)
echo "ALB dimension: $ALB_DIMENSION"
echo ""

elapsed=0
checks_passed=0

while [ "$elapsed" -lt "$MONITOR_DURATION_S" ]; do
  sleep "$POLL_INTERVAL_S"
  elapsed=$((elapsed + POLL_INTERVAL_S))

  # Fetch metrics
  requests_5xx=$(get_metric "HTTPCode_Target_5XX_Count" "Sum" "$ALB_DIMENSION")
  requests_2xx=$(get_metric "HTTPCode_Target_2XX_Count" "Sum" "$ALB_DIMENSION")
  requests_total=$(get_metric "RequestCount" "Sum" "$ALB_DIMENSION")
  latency_p99=$(get_metric "TargetResponseTime" "p99" "$ALB_DIMENSION")

  # Sanitise nulls
  requests_5xx="${requests_5xx:-0}"; requests_5xx="${requests_5xx/None/0}"
  requests_total="${requests_total:-0}"; requests_total="${requests_total/None/0}"
  latency_p99="${latency_p99:-0}"; latency_p99="${latency_p99/None/0}"

  # Calculate error rate (avoid division by zero)
  if [ "${requests_total%.*}" -gt 0 ] 2>/dev/null; then
    error_rate=$(awk "BEGIN { printf \"%.2f\", (${requests_5xx} / ${requests_total}) * 100 }")
  else
    error_rate="0.00"
    echo "  [${elapsed}s] No traffic yet — waiting for requests..."
    continue
  fi

  # Convert latency to ms
  latency_ms=$(awk "BEGIN { printf \"%.0f\", ${latency_p99} * 1000 }")

  checks_passed=$((checks_passed + 1))
  echo "  [${elapsed}s] 5XX: ${error_rate}% (threshold: ${ERROR_RATE_THRESHOLD}%) | p99: ${latency_ms}ms (threshold: ${LATENCY_THRESHOLD_MS}ms) | requests: ${requests_total%.*}"

  # Check error rate threshold
  if awk "BEGIN { exit !(${error_rate} > ${ERROR_RATE_THRESHOLD}) }"; then
    echo ""
    echo "FAIL: Error rate ${error_rate}% exceeds threshold ${ERROR_RATE_THRESHOLD}%"
    echo "Canary is unhealthy — triggering rollback."
    exit 1
  fi

  # Check latency threshold
  if [ "$latency_ms" -gt "$LATENCY_THRESHOLD_MS" ] 2>/dev/null; then
    echo ""
    echo "FAIL: p99 latency ${latency_ms}ms exceeds threshold ${LATENCY_THRESHOLD_MS}ms"
    echo "Canary is unhealthy — triggering rollback."
    exit 1
  fi
done

echo ""
echo "=== Canary Healthy ==="
echo "Passed ${checks_passed} checks over ${MONITOR_DURATION_S}s. Promoting to full rollout."
exit 0
