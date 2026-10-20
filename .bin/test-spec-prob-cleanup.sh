#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'spec-prob cleanup: %s\n' "$*" >&2
  exit 1
}

source_root=$(git rev-parse --show-toplevel)
scratch=${TMPDIR:-$source_root/.tmp/opencode}
mkdir -p "$scratch"
fixture=$(mktemp -d "$scratch/points-spec-prob-test.XXXXXX")
root=$fixture/repo
mkdir -p "$root/docs/spec"
cp "$source_root/Makefile" "$root/Makefile"
cp "$source_root/docs/spec/points.target.spec.tex" "$root/docs/spec/points.target.spec.tex"
output=$root/docs/spec/points.target.spec.fuzz
lock=$root/docs/spec/.points-target-spec-prob.lock
fake=$fixture/probcli
created_output=false
holder=''
release=''

cleanup() {
  if test -n "$holder"; then
    test -z "$release" || touch "$release"
    kill "$holder" >/dev/null 2>&1 || true
    wait "$holder" >/dev/null 2>&1 || true
  fi
  rm -rf "$fixture"
  if test "$created_output" = true; then
    rm -f "$output"
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

test ! -e "$output" && test ! -L "$output" || fail 'test requires an absent ProB output path'
test ! -e "$lock" && test ! -L "$lock" || fail 'test requires an absent ProB lock path'

cat >"$fixture/fuzz" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
test "$1" = docs/spec/points.target.spec.tex
SH
cat >"$fake" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: > docs/spec/points.target.spec.fuzz
case ${FAKE_PROB_MODE:-success} in
  success) echo 'No counter-example to ASSERTION exists' ;;
  missing-verdict) echo 'assertion command returned without a verdict' ;;
  truncated)
    echo 'No counter-example to ASSERTION exists'
    echo 'model_check_incomplete'
    ;;
  success-child)
    (sleep 0.2; echo late-writer > docs/spec/points.target.spec.fuzz) &
    echo 'No counter-example to ASSERTION exists'
    ;;
  failure) exit 7 ;;
  failure-child)
    (sleep 0.2; echo late-writer > docs/spec/points.target.spec.fuzz) &
    exit 7
    ;;
  signal) kill -TERM $$ ;;
  signal-parent-on-start)
    kill -TERM "$PPID"
    sleep 0.2
    ;;
  hold)
    : > "$FAKE_PROB_READY"
    while test ! -e "$FAKE_PROB_RELEASE"; do sleep 0.01; done
    echo 'No counter-example to ASSERTION exists'
    ;;
  hold-ignore-term)
    trap '' TERM
    : > "$FAKE_PROB_READY"
    while test ! -e "$FAKE_PROB_RELEASE"; do sleep 0.01; done
    echo 'No counter-example to ASSERTION exists'
    ;;
  *) exit 9 ;;
esac
SH
chmod 0700 "$fixture/fuzz" "$fake"

PATH="$fixture:$PATH" FAKE_PROB_MODE=success make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null
test ! -e "$output" || fail 'success left generated output behind'

if PATH="$fixture:$PATH" FAKE_PROB_MODE=failure make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'failing ProB unexpectedly succeeded'
fi
test ! -e "$output" || fail 'failure left generated output behind'

if PATH="$fixture:$PATH" FAKE_PROB_MODE=missing-verdict make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'ProB without an assertion verdict unexpectedly succeeded'
fi
test ! -e "$output" || fail 'missing verdict left generated output behind'

if PATH="$fixture:$PATH" FAKE_PROB_MODE=truncated make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'incomplete ProB result unexpectedly succeeded'
fi
test ! -e "$output" || fail 'incomplete result left generated output behind'

if PATH="$fixture:$PATH" FAKE_PROB_MODE=failure-child make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'failing ProB with child writer unexpectedly succeeded'
fi
sleep 0.3
test ! -e "$output" || fail 'surviving child writer recreated output after cleanup'
test ! -e "$lock" || fail 'failure with child writer left lock behind'

if PATH="$fixture:$PATH" FAKE_PROB_MODE=success-child make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  :
else
  fail 'successful ProB with child writer unexpectedly failed'
fi
sleep 0.3
test ! -e "$output" || fail 'successful child writer recreated output after cleanup'
test ! -e "$lock" || fail 'success with child writer left lock behind'

if PATH="$fixture:$PATH" FAKE_PROB_MODE=signal make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'signalled ProB unexpectedly succeeded'
fi
test ! -e "$output" || fail 'signal left generated output behind'

if PATH="$fixture:$PATH" FAKE_PROB_MODE=signal-parent-on-start make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'launch-boundary interruption unexpectedly succeeded'
fi
test ! -e "$output" || fail 'launch-boundary interruption left output behind'
test ! -e "$lock" || fail 'launch-boundary interruption left lock behind'

printf 'operator-owned\n' >"$output"
created_output=true
before=$(cat "$output")
if PATH="$fixture:$PATH" FAKE_PROB_MODE=success make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'target replaced a pre-existing output path'
fi
after=$(cat "$output")
test "$after" = "$before" || fail 'pre-existing output content changed'

rm -f "$output"
created_output=false
dangling_target=$fixture/dangling-target
test ! -e "$dangling_target" && test ! -L "$dangling_target" ||
  fail 'unique dangling target unexpectedly exists'
ln -s "$dangling_target" "$output"
created_output=true
before=$(readlink "$output")
if PATH="$fixture:$PATH" FAKE_PROB_MODE=success make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'target followed or replaced a pre-existing dangling symlink'
fi
test -L "$output" || fail 'dangling symlink was removed'
after=$(readlink "$output")
test "$after" = "$before" || fail 'dangling symlink target changed'
test ! -e "$dangling_target" || fail 'dangling symlink target was created'

rm -f "$output"
created_output=false
ready=$fixture/holder-ready
release=$fixture/holder-release
PATH="$fixture:$PATH" FAKE_PROB_MODE=hold FAKE_PROB_READY="$ready" FAKE_PROB_RELEASE="$release" \
  make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1 &
holder=$!
for ((attempt=0; attempt<500; attempt++)); do
  test -e "$ready" && break
  sleep 0.01
done
test -e "$ready" || fail 'first concurrent invocation did not reach fake ProB'
if PATH="$fixture:$PATH" FAKE_PROB_MODE=success make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'second concurrent invocation bypassed the lock'
fi
touch "$release"
wait "$holder"
holder=''
test ! -e "$output" && test ! -L "$output" || fail 'concurrent run left output behind'
test ! -e "$lock" && test ! -L "$lock" || fail 'concurrent run left lock behind'

rm -f "$ready" "$release"
PATH="$fixture:$PATH" FAKE_PROB_MODE=hold FAKE_PROB_READY="$ready" FAKE_PROB_RELEASE="$release" \
  make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1 &
holder=$!
for ((attempt=0; attempt<500; attempt++)); do
  test -e "$ready" && break
  sleep 0.01
done
test -e "$ready" || fail 'signalled Make invocation did not reach fake ProB'
kill -TERM "$holder"
if wait "$holder"; then
  fail 'signalled Make invocation unexpectedly succeeded'
fi
holder=''
for ((attempt=0; attempt<500; attempt++)); do
  test ! -e "$output" && test ! -e "$lock" && break
  sleep 0.01
done
test ! -e "$output" && test ! -L "$output" || fail 'signalled Make left output behind'
test ! -e "$lock" && test ! -L "$lock" || fail 'signalled Make left lock behind'

acquire_bin=$fixture/acquire-bin
mkdir "$acquire_bin"
cat >"$acquire_bin/mkdir" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
/bin/mkdir "$@"
kill -TERM "$PPID"
SH
chmod 0700 "$acquire_bin/mkdir"
if PATH="$acquire_bin:$fixture:$PATH" FAKE_PROB_MODE=success make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1; then
  fail 'interrupted lock acquisition unexpectedly succeeded'
fi
test ! -e "$output" && test ! -L "$output" || fail 'interrupted acquisition left output behind'
test ! -e "$lock" && test ! -L "$lock" || fail 'interrupted acquisition left lock behind'

rm -f "$ready" "$release"
PATH="$fixture:$PATH" FAKE_PROB_MODE=hold-ignore-term FAKE_PROB_READY="$ready" FAKE_PROB_RELEASE="$release" \
  make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1 &
holder=$!
for ((attempt=0; attempt<500; attempt++)); do
  test -e "$ready" && break
  sleep 0.01
done
test -e "$ready" || fail 'parent-death run did not reach TERM-resistant checker'
kill -KILL "$holder"
if wait "$holder"; then
  fail 'killed Make invocation unexpectedly succeeded'
fi
holder=''
for ((attempt=0; attempt<500; attempt++)); do
  test ! -e "$output" && test ! -e "$lock" && break
  sleep 0.01
done
test ! -e "$output" && test ! -L "$output" || fail 'parent death left output behind'
test ! -e "$lock" && test ! -L "$lock" || fail 'parent death left lock behind'

rm -f "$ready" "$release"
set -m
PATH="$fixture:$PATH" FAKE_PROB_MODE=hold FAKE_PROB_READY="$ready" FAKE_PROB_RELEASE="$release" \
  make -C "$root" --no-print-directory spec-prob PROB="$fake" >/dev/null 2>&1 &
holder=$!
for ((attempt=0; attempt<500; attempt++)); do
  test -e "$ready" && break
  sleep 0.01
done
test -e "$ready" || fail 'process-group interrupt did not reach fake ProB setup'
kill -INT -- "-$holder"
if wait "$holder"; then
  fail 'process-group interrupt unexpectedly succeeded'
fi
holder=''
set +m
for ((attempt=0; attempt<500; attempt++)); do
  test ! -e "$output" && test ! -e "$lock" && break
  sleep 0.01
done
test ! -e "$output" && test ! -L "$output" || fail 'process-group interrupt left output behind'
test ! -e "$lock" && test ! -L "$lock" || fail 'process-group interrupt left lock behind'

echo 'spec-prob cleanup tests: PASS'
