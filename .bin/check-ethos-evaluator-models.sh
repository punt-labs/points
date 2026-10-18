#!/usr/bin/env bash
set -euo pipefail

evaluators=(gstack-architect gstack-reviewer)

for evaluator in "${evaluators[@]}"; do
  file=".opencode/agents/${evaluator}.md"
  model=$(sed -n 's/^model: //p' "$file")
  case "$model" in
    bifrost/openai/gpt-5.6-*|bifrost/openai/gpt-6-*) ;;
    *)
      printf 'Ethos evaluator %s must use a preferred Bedrock OpenAI model, got %s\n' \
        "$evaluator" "${model:-<missing>}" >&2
      exit 1
      ;;
  esac
done

if grep -Eq '^\| .* \| `gstack-qa` \|$' docs/WORKFLOW.md; then
  echo 'gstack-qa must not appear in the evaluator column' >&2
  exit 1
fi
