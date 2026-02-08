CHART_DIR := charts/gvm-lite-stack

.PHONY: fmt lint test render validate check

fmt:
	@command -v yamlfmt >/dev/null 2>&1 || (echo "yamlfmt not installed" && exit 1)
	yamlfmt -match_type doublestar -gitignore_excludes \
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
	helm template $(CHART_DIR) | kubeconform -strict -ignore-missing-schemas

check: lint test validate
