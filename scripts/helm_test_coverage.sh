#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${1:-charts/gvm-lite-stack}"

# Make paths relative to repo root, not current directory
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmpl_dir="$REPO_ROOT/$CHART_DIR/templates"
test_dir="$REPO_ROOT/$CHART_DIR/tests"

if [[ ! -d "$tmpl_dir" ]]; then
  echo "Templates directory not found: $tmpl_dir"
  exit 1
fi

if [[ ! -d "$test_dir" ]]; then
  echo "Tests directory not found: $test_dir"
  exit 1
fi

templates="$(find "$tmpl_dir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) ! -name "_helpers.tpl" -print | sort)"
tests="$(find "$test_dir" -type f -name "*_test.yaml" -print | sort)"

total="$(printf "%s\n" "$templates" | sed '/^$/d' | wc -l | tr -d ' ')"
covered=0
missing=""

# Loop templates
while IFS= read -r t; do
  [[ -z "$t" ]] && continue
  rel="templates/$(basename "$t")"

  found=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if grep -qE "^\s*-\s*$rel\s*$" "$f"; then
      found=1
      break
    fi
  done <<< "$tests"

  if [[ "$found" -eq 1 ]]; then
    covered=$((covered+1))
  else
    missing="${missing}\n  - ${rel}"
  fi
done <<< "$templates"

pct=0
if [[ "$total" -gt 0 ]]; then
  pct=$(( 100 * covered / total ))
fi

echo "Helm test coverage: $covered/$total (${pct}%)"

if [[ -n "$missing" ]]; then
  echo ""
  echo "Missing tests for:"
  echo -e "$missing"
  exit 2
fi
