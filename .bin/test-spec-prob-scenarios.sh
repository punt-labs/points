#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'spec-prob Scenario A tests: %s\n' "$*" >&2
  exit 1
}

root=$PWD
scratch=${TMPDIR:-$root/.tmp/opencode}
mkdir -p "$scratch"
fixture=$(mktemp -d "$scratch/points-spec-prob-a-test.XXXXXXXX")
cleanup() {
  rm -rf "$fixture"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

source_spec=$root/docs/spec/points.target.spec.tex
generator=$root/.bin/generate-spec-prob.py

# Determinism is checked across separate processes, not only in-memory rendering.
python3 "$generator" generate --source "$source_spec" \
  --output "$fixture/first.tex" --manifest "$fixture/first.json"
python3 "$generator" generate --source "$source_spec" \
  --output "$fixture/second.tex" --manifest "$fixture/second.json"
cmp "$fixture/first.tex" "$fixture/second.tex"
cmp "$fixture/first.json" "$fixture/second.json"

# The source split, generated projection, and manifest are one structural contract.
python3 - "$source_spec" "$fixture/first.tex" "$fixture/first.json" <<'PY'
from hashlib import sha256
import json
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_bytes()
model = Path(sys.argv[2]).read_bytes()
manifest = json.loads(Path(sys.argv[3]).read_text())

routing = "types.routing-carriers"
transaction = "types.transaction-carriers"

def marked_body(identifier: str) -> bytes:
    begin = f"% POINTS-CHECK BEGIN {identifier} type\n".encode()
    end = f"% POINTS-CHECK END {identifier}\n".encode()
    assert source.count(begin) == 1 and source.count(end) == 1
    start = source.index(begin) + len(begin)
    finish = source.index(end, start)
    return source[start:finish]

routing_body = marked_body(routing)
transaction_body = marked_body(transaction)
assert source.count(
    b"% POINTS-CHECK END types.routing-carriers\n\n"
    b"% POINTS-CHECK BEGIN types.transaction-carriers type\n"
) == 1

expected_carriers = [
    "ModelId", "Provider", "Source", "JSONPointer", "Path", "Identity",
    "Owner", "Mode", "ByteString", "Delta", "FileImage",
]
declared = []
for paragraph in re.findall(
    rb"\\begin\{zed\}\r?\n(.*?)\\end\{zed\}\r?\n", source, re.S
):
    given = re.fullmatch(rb"[ \t]*\[([A-Za-z0-9_, \t\r\n]+)\]\r?\n", paragraph)
    if given:
        declared.extend(
            name.decode()
            for name in re.findall(rb"[A-Za-z][A-Za-z0-9]*", given.group(1))
        )
assert all(declared.count(name) == 1 for name in expected_carriers)

assert model.count(transaction_body) == 1
assert routing_body not in model
assert b"JSONPointer" in model and b"ptrConflict" in model
assert b"JSONPointer = \\{ ptrConflict \\}" in model
assert b"\\# JSONPointer = 1" in model
for forbidden in (b"ModelId", b"Provider", b"Source", b"solA", b"providerA", b"sourceA"):
    assert not re.search(rb"(?<![A-Za-z0-9])" + forbidden + rb"(?![A-Za-z0-9])", model)

assert manifest["source_blocks"][:2] == [routing, transaction]
assert manifest["block_sha256"][routing] == sha256(routing_body).hexdigest()
assert manifest["block_sha256"][transaction] == sha256(transaction_body).hexdigest()
assert routing in manifest["omitted_projection_blocks"]
assert routing not in manifest["projection_blocks"]
assert transaction in manifest["projection_blocks"]
assert transaction in manifest["copied_projection_blocks"]
assert manifest["scenario_cardinalities"] == {
    "JSONPointer": 1,
    "Path": 4,
    "Identity": 1,
    "Owner": 1,
    "Mode": 1,
    "ByteString": 3,
    "Delta": 4,
    "FileImage": 6,
}
PY

# Build carrier marker and inventory mutations without platform-specific sed.
python3 - "$source_spec" "$fixture" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_bytes()
fixture = Path(sys.argv[2])
routing_begin = b"% POINTS-CHECK BEGIN types.routing-carriers type\n"
routing_end = b"% POINTS-CHECK END types.routing-carriers\n"
transaction_begin = b"% POINTS-CHECK BEGIN types.transaction-carriers type\n"
transaction_end = b"% POINTS-CHECK END types.transaction-carriers\n"

def write(name: str, data: bytes) -> None:
    fixture.joinpath(name + ".tex").write_bytes(data)

def block(begin: bytes, end: bytes) -> bytes:
    start = source.index(begin)
    finish = source.index(end, start) + len(end)
    return source[start:finish]

routing_block = block(routing_begin, routing_end)
transaction_block = block(transaction_begin, transaction_end)
assert all(source.count(marker) == 1 for marker in (
    routing_begin, routing_end, transaction_begin, transaction_end,
))

write("missing-carrier-marker", source.replace(routing_begin, b"", 1))
write(
    "malformed-carrier-marker",
    source.replace(
        routing_begin,
        b"% POINTS-CHECK BEGIN types.routing-carriers wrong-kind\n",
        1,
    ),
)
write(
    "wrong-kind-carrier-marker",
    source.replace(
        routing_begin,
        b"% POINTS-CHECK BEGIN types.routing-carriers monitor\n",
        1,
    ),
)
placeholder = b"% POINTS-CHECK SWAP PLACEHOLDER\n"
swapped = source.replace(routing_block, placeholder, 1)
swapped = swapped.replace(transaction_block, routing_block, 1)
write("reordered-carrier-markers", swapped.replace(placeholder, transaction_block, 1))
write("duplicated-carrier-marker", source.replace(routing_block, routing_block * 2, 1))
write("mismatched-carrier-marker", source.replace(routing_end, transaction_end, 1))
write("nested-carrier-marker", source.replace(routing_begin, routing_begin + transaction_begin, 1))
write(
    "routing-inventory",
    source.replace(
        b"\t[ModelId, Provider, Source]\n",
        b"\t[ModelId, Provider, JSONPointer]\n",
        1,
    ),
)
write(
    "transaction-inventory",
    source.replace(
        b"\t[JSONPointer, Path, Identity, Owner, Mode, ByteString, Delta, FileImage]\n",
        b"\t[Source, Path, Identity, Owner, Mode, ByteString, Delta, FileImage]\n",
        1,
    ),
)
write(
    "moved-pointer-inventory",
    source.replace(
        b"\t[ModelId, Provider, Source]\n",
        b"\t[ModelId, Provider, JSONPointer]\n",
        1,
    ).replace(
        b"\t[JSONPointer, Path, Identity, Owner, Mode, ByteString, Delta, FileImage]\n",
        b"\t[Source, Path, Identity, Owner, Mode, ByteString, Delta, FileImage]\n",
        1,
    ),
)
PY

expect_generation_failure() {
  name=$1
  diagnostic=$2
  if python3 "$generator" generate --source "$fixture/$name.tex" \
    --output "$fixture/$name.out.tex" --manifest "$fixture/$name.out.json" \
    >"$fixture/$name.out" 2>&1; then
    fail "$name unexpectedly generated a model"
  fi
  test ! -e "$fixture/$name.out.tex" || fail "$name failure wrote a model"
  test ! -e "$fixture/$name.out.json" || fail "$name failure wrote a manifest"
  grep -q "$diagnostic" "$fixture/$name.out" ||
    fail "$name lacked its focused diagnostic"
}

expect_generation_failure missing-carrier-marker 'unmatched source end'
expect_generation_failure malformed-carrier-marker 'malformed POINTS-CHECK marker'
expect_generation_failure wrong-kind-carrier-marker 'source marker identifiers, kinds, or order changed'
expect_generation_failure reordered-carrier-markers 'source marker identifiers, kinds, or order changed'
expect_generation_failure duplicated-carrier-marker 'duplicate source block types.routing-carriers'
expect_generation_failure mismatched-carrier-marker 'does not match types.routing-carriers'
expect_generation_failure nested-carrier-marker 'nested source block'
expect_generation_failure routing-inventory 'routing carrier inventory changed'
expect_generation_failure transaction-inventory 'transaction carrier inventory changed'
expect_generation_failure moved-pointer-inventory 'routing carrier inventory changed'

repo=$fixture/repo
mkdir -p "$repo/.bin" "$repo/docs/spec" "$repo/.tmp/opencode"
cp "$root/Makefile" "$repo/Makefile"
cp "$source_spec" "$repo/docs/spec/points.target.spec.tex"
cp "$generator" "$repo/.bin/generate-spec-prob.py"

cat >"$fixture/fuzz" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
test -f "$1"
SH

cat >"$fixture/probcli" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if test "${1:-}" = -version; then
  echo 'ProB fake 1.0'
  exit 0
fi
if test "${1:-}" = -help; then
  echo '-init -model_check -goal -his -dot state_space'
  exit 0
fi

phase=lifecycle
dot=''
trace=''
previous=''
for argument in "$@"; do
  if test "$argument" = -init; then phase=init; fi
  if test "$previous" = dot-file; then dot=$argument; previous=''; continue; fi
  if test "$previous" = trace-file; then trace=$argument; previous=''; continue; fi
  if test "$argument" = state_space; then previous=dot-file; continue; fi
  if test "$argument" = -his; then previous=trace-file; continue; fi
done

mode=${FAKE_PROB_MODE:-success}
case $mode:$phase in
  failure:init) exit 7 ;;
  timeout:init) echo 'TIME OUT'; exit 0 ;;
  hold-init:init)
    echo $$ >"$FAKE_PROB_PID"
    : >"$FAKE_PROB_READY"
    trap 'exit 143' TERM HUP INT
    while :; do sleep 0.05; done
    ;;
esac
native=false
case $mode in
  native-*) native=true ;;
esac

operations='CandidateFailure CreateStage CreateStageFailure WriteStage WriteStageFailure FileSyncStage FileSyncStageFailure CloseStage CloseStageFailure BeginRevalidation RevalidationSuccess RevalidationIOFailure CommitAbsent CommitAbsentFailure ConfirmConfigSuccess ConfirmConfigFailure BeginCleanup UnlinkOwned CleanupUnlinkFailed CleanupInspectionFailed EndCleanupSweep CleanupSyncSuccess CleanupSyncFailure ReleaseSuccess ReleaseFailure ReportDelivered ReportFailed FinishTransaction ObserveCancellation ProcessDeath PowerLoss'
for operation in $operations; do
  echo "Z operation: Check$operation"
done

if test "$phase" = init; then
  if test "$native" = true; then
    case $mode in
      native-missing-state)
        echo 'Coverage: [deadlocked:0,invariant_violated:0,TOTAL_TRANSITIONS,2]'
        ;;
      native-zero-state)
        echo 'Coverage: [STATES (0),deadlocked:0,invariant_violated:0,TOTAL_TRANSITIONS,2]'
        ;;
      native-mixed-zero-state)
        echo 'States analysed: 0'
        echo 'Coverage: [STATES (3),deadlocked:0,invariant_violated:0,TOTAL_TRANSITIONS,2]'
        ;;
      native-dual-counts)
        echo 'States analysed: 2'
        echo 'Coverage: [STATES (3),deadlocked:0,invariant_violated:0,TOTAL_TRANSITIONS,2]'
        ;;
      *)
        echo 'Coverage: [STATES (3),deadlocked:0,invariant_violated:0,TOTAL_TRANSITIONS,2]'
        ;;
    esac
    case $mode in
      native-init-counterexample) echo '*** COUNTER EXAMPLE FOUND ***' ;;
      native-init-error-total) echo '! Total Errors: 1, Warnings:0' ;;
    esac
  elif test "$mode" = zero-state; then
    echo 'States analysed: 0'
  else
    echo 'States analysed: 1'
  fi
else
  if test "$native" = true; then
    case $mode in
      native-missing-found-goal) ;;
      *) echo 'Found GOAL in state id 16' ;;
    esac
    echo '*** COUNTER EXAMPLE FOUND ***'
    case $mode in
      native-missing-goal-found) ;;
      *)
        echo 'goal_found'
        echo '! *** error occurred ***'
        echo '! goal_found'
        ;;
    esac
    if test "$mode" = native-nongoal-error; then
      echo '! invariant_violated'
    fi
    case $mode in
      native-missing-transition)
        echo 'Coverage: [STATES (16),deadlocked:0,invariant_violated:0]'
        ;;
      native-zero-transition)
        echo 'Coverage: [STATES (16),deadlocked:0,invariant_violated:0,TOTAL_TRANSITIONS,0]'
        ;;
      native-mixed-zero-transition)
        echo 'Transitions fired: 0'
        echo 'Coverage: [STATES (16),deadlocked:0,invariant_violated:0,TOTAL_TRANSITIONS,15]'
        ;;
      native-dual-counts)
        echo 'States analysed: 4'
        echo 'Transitions fired: 7'
        echo 'Coverage: [STATES (16),deadlocked:0,invariant_violated:0,TOTAL_TRANSITIONS,15]'
        ;;
      *)
        echo 'Coverage: [STATES (16),deadlocked:0,invariant_violated:0,TOTAL_TRANSITIONS,15]'
        ;;
    esac
    if test "$mode" = native-excess-errors; then
      echo '! Total Errors: 2, Warnings:0'
    else
      echo '! Total Errors: 1, Warnings:0'
    fi
  else
    echo 'States analysed: 16'
    echo 'Transitions fired: 15'
  fi
  if test "$native" = false && test "$mode" != missing-verdict; then
    echo 'Found GOAL in state id 16'
    echo 'goal_found'
  fi
fi

txn_fields='visibleNS durableNS pendingCount pendingDeltaOne pendingDeltaTwo pendingDeltaThree pendingDeltaFour pendingDeltaFive pendingDeltaSix visibleImages syncedImages intendedImages snapshotImages dirtyChoices stageIDs sealedIDs closeOK published publicationImages owned cleanupDue cleanupPending retainedResults cleanupNotes configPath backupPath configStage backupStage candidateID backupIDs expectedConfig conflicts phase committed configSyncAck cancelled lockHeld backupProgress life reportState revalidationPassed confirmationAttempted cleanupWork cleanupTried cleanupSyncAttempted releaseAttempted events inputAccepted writeStarted noOp namespaceMutated snapshotLinks currentLinks snapshotAccess currentAccess ownedBackupPublication backupAbsenceConfirmed authorizationPassed authorizedTransport insecureConsent'
monitor_fields='seen linksInjected accessInjected replacementInjected cancellationAfterCommit deathKind lastCrashMask preCrashActiveCount publicationSeen publicationQualified configPublicationSeen revalidatedAtConfigPublication backupReadyAtConfigPublication replacementPath replacementIdentity badRevalidation badFilePublication badBackupOrder badReplacementUnlink badPrematureReport badPostDeathStep badImageCoverage badFinalImage badRetainedCleanup'
{
  echo 'digraph {'
  printf 'n1 [label="'
  assignment_index=0
  for field in $txn_fields $monitor_fields; do
    case $mode:$field in
      missing-field:insecureConsent | native-missing-field:insecureConsent) continue ;;
    esac
    value=fake
    case $phase:$field in
      init:visibleNS | lifecycle:visibleNS)
        if test "$native" = true; then value='\{first,second\}'; fi
        ;;
      init:pendingDeltaOne | init:pendingDeltaTwo | init:pendingDeltaThree | \
        init:pendingDeltaFour | init:pendingDeltaFive | init:pendingDeltaSix)
        value=dIdle
        ;;
      init:life) value=running ;;
      init:phase) value=staging ;;
      lifecycle:life) value=ended ;;
      lifecycle:phase) value=finished ;;
      lifecycle:reportState) value=reportDelivered ;;
      lifecycle:committed | lifecycle:configSyncAck) value=yes ;;
      lifecycle:lockHeld) value=no ;;
    esac
    rendered_field=$field
    if test "$native" = true && test "$field" = intendedImages; then
      rendered_field='intendedImages(idCandidate)'
    fi
    if test "$native" = true; then
      if test "$assignment_index" -gt 0; then
        if test $((assignment_index % 3)) -eq 0; then
          printf ',\\n'
        else
          printf ','
        fi
      fi
      printf '%s = %s' "$rendered_field" "$value"
    else
      printf '%s = %s\\n' "$rendered_field" "$value"
    fi
    assignment_index=$((assignment_index + 1))
  done
  case $mode in
    duplicate-field) printf 'life = conflicting\\n' ;;
    native-duplicate-field) printf ',\\nlife = conflicting' ;;
  esac
  echo '"];}'
} >"$dot"

if test "$phase" = lifecycle; then
  cat >"$trace" <<'TRACE'
CheckCreateStage
CheckWriteStage
CheckFileSyncStage
CheckCloseStage
CheckBeginRevalidation
CheckRevalidationSuccess
CheckCommitAbsent
CheckConfirmConfigSuccess
CheckBeginCleanup
CheckUnlinkOwned
CheckEndCleanupSweep
CheckCleanupSyncSuccess
CheckReleaseSuccess
CheckReportDelivered
CheckFinishTransaction
TRACE
else
  : >"$trace"
fi
SH
chmod 0700 "$fixture/fuzz" "$fixture/probcli"

run_make() {
  mode=$1
  shift
  PATH="$fixture:$PATH" FAKE_PROB_MODE=$mode \
    make -C "$repo" --no-print-directory spec-prob-a-smoke \
    PROB="$fixture/probcli" "$@"
}

run_make success >"$fixture/success.out"
grep -q 'Scenario A smoke: PASS' "$fixture/success.out" ||
  fail 'successful fake run did not report PASS'

run_make native-success >"$fixture/native-success.out"
grep -q 'Scenario A smoke: PASS' "$fixture/native-success.out" ||
  fail 'successful native-shaped fake run did not report PASS'

run_make native-dual-counts >"$fixture/native-dual-counts.out"
grep -q 'Scenario A smoke: PASS' "$fixture/native-dual-counts.out" ||
  fail 'differing positive legacy/native counts did not report PASS'

for mode in \
  missing-verdict zero-state failure timeout missing-field duplicate-field \
  native-zero-state native-zero-transition native-missing-state \
  native-missing-transition native-mixed-zero-state \
  native-mixed-zero-transition native-missing-field native-duplicate-field \
  native-init-counterexample native-init-error-total native-nongoal-error \
  native-excess-errors \
  native-missing-found-goal native-missing-goal-found; do
  if run_make "$mode" >"$fixture/$mode.out" 2>&1; then
    fail "$mode fake checker result unexpectedly passed"
  fi
done

# Two simultaneous cooperative runs must use different evidence directories.
run_make success >"$fixture/concurrent-one.out" 2>&1 &
one=$!
run_make success >"$fixture/concurrent-two.out" 2>&1 &
two=$!
wait "$one"
wait "$two"
one_dir=$(sed -n 's/^Scenario A smoke: PASS (\(.*\))$/\1/p' "$fixture/concurrent-one.out")
two_dir=$(sed -n 's/^Scenario A smoke: PASS (\(.*\))$/\1/p' "$fixture/concurrent-two.out")
test -n "$one_dir" && test -n "$two_dir" || fail 'concurrent run did not report evidence paths'
test "$one_dir" != "$two_dir" || fail 'concurrent runs shared an evidence directory'
test -f "$repo/$one_dir/inputs.json" && test -f "$repo/$two_dir/inputs.json" ||
  fail 'concurrent run evidence is incomplete'

# Interrupting Make must stop the invocation-owned checker and retain evidence.
ready=$fixture/interrupt.ready
pid_file=$fixture/interrupt.pid
PATH="$fixture:$PATH" FAKE_PROB_MODE=hold-init FAKE_PROB_READY="$ready" \
  FAKE_PROB_PID="$pid_file" make -C "$repo" --no-print-directory \
  spec-prob-a-smoke PROB="$fixture/probcli" >"$fixture/interrupt.out" 2>&1 &
holder=$!
for ((attempt = 0; attempt < 500; attempt++)); do
  test -e "$ready" && break
  sleep 0.01
done
test -e "$ready" || fail 'interruption fake did not reach initialization'
kill -TERM "$holder"
if wait "$holder"; then fail 'interrupted Scenario A target unexpectedly passed'; fi
checker_pid=$(cat "$pid_file")
for ((attempt = 0; attempt < 500; attempt++)); do
  kill -0 "$checker_pid" 2>/dev/null || break
  sleep 0.01
done
if kill -0 "$checker_pid" 2>/dev/null; then
  kill -KILL "$checker_pid" 2>/dev/null || true
  fail 'interruption left the fake checker running'
fi
grep -q 'Scenario A evidence preserved in' "$fixture/interrupt.out" ||
  fail 'interruption did not identify retained evidence'

echo 'spec-prob Scenario A tests: PASS'
