CHART_DIR := charts/gvm-lite-stack

.PHONY: fmt fmt-check lint test render validate check cover

fmt:
	@command -v yamlfmt >/dev/null 2>&1 || (echo "yamlfmt not installed" && exit 1)
	yamlfmt -match_type doublestar \
	  "charts/**/Chart.yaml" \
	  "charts/**/values.yaml" \
	  "charts/**/values-*.yaml" \
	  "charts/**/tests/**/*.y*ml"

fmt-check:
	@command -v yamlfmt >/dev/null 2>&1 || (echo "yamlfmt not installed" && exit 1)
	yamlfmt -lint -match_type doublestar \
	  "charts/**/Chart.yaml" \
	  "charts/**/values.yaml" \
	  "charts/**/values-*.yaml" \
	  "charts/**/tests/**/*.y*ml"

lint:
	helm lint $(CHART_DIR)

test:
	helm unittest $(CHART_DIR)

render:
	helm template $(CHART_DIR) > /tmp/gvm-lite-stack.rendered.yaml

validate:
	@command -v kubeconform >/dev/null 2>&1 || (echo "kubeconform not installed" && exit 1)
	helm template $(CHART_DIR) | kubeconform -strict -ignore-missing-schemas

check: fmt-check lint test validate

cover:
	./scripts/helm_test_coverage.sh $(CHART_DIR)
