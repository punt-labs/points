#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'spec-prob cleanup: %s\n' "$*" >&2
  exit 1
}

root=$(git rev-parse --show-toplevel)
output=$root/docs/spec/points.target.spec.fuzz
scratch=${TMPDIR:-$root/.tmp/opencode}
mkdir -p "$scratch"
fake=$(mktemp "$scratch/points-fake-prob.XXXXXX")
created_output=false

cleanup() {
  rm -f "$fake"
  if test "$created_output" = true; then
    rm -f "$output"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

test ! -e "$output" && test ! -L "$output" || fail 'test requires an absent ProB output path'

cat >"$fake" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: > docs/spec/points.target.spec.fuzz
case ${FAKE_PROB_MODE:-success} in
  success) echo 'No counter-example to ASSERTION exists' ;;
  failure) exit 7 ;;
  signal) kill -TERM $$ ;;
  *) exit 9 ;;
esac
SH
chmod 0700 "$fake"

FAKE_PROB_MODE=success make --no-print-directory spec-prob PROB="$fake" >/dev/null
test ! -e "$output" || fail 'success left generated output behind'

if FAKE_PROB_MODE=failure make --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'failing ProB unexpectedly succeeded'
fi
test ! -e "$output" || fail 'failure left generated output behind'

if FAKE_PROB_MODE=signal make --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'signalled ProB unexpectedly succeeded'
fi
test ! -e "$output" || fail 'signal left generated output behind'

printf 'operator-owned\n' >"$output"
created_output=true
before=$(cat "$output")
if FAKE_PROB_MODE=success make --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'target replaced a pre-existing output path'
fi
after=$(cat "$output")
test "$after" = "$before" || fail 'pre-existing output content changed'

rm -f "$output"
created_output=false
dangling_target=$scratch/points-dangling-prob-target
rm -f "$dangling_target"
ln -s "$dangling_target" "$output"
created_output=true
before=$(readlink "$output")
if FAKE_PROB_MODE=success make --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'target followed or replaced a pre-existing dangling symlink'
fi
test -L "$output" || fail 'dangling symlink was removed'
after=$(readlink "$output")
test "$after" = "$before" || fail 'dangling symlink target changed'
test ! -e "$dangling_target" || fail 'dangling symlink target was created'

echo 'spec-prob cleanup tests: PASS'
