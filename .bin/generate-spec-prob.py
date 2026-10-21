#!/usr/bin/env python3
"""Generate and validate the bounded ProB Scenario A smoke model.

This intentionally understands only the marked transaction library in
points.target.spec.tex.  It is not a Z parser or a general ProB runner.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys


class ValidationError(Exception):
    """The authoritative source or checker evidence is not as expected."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


BEGIN = re.compile(
    rb"^% POINTS-CHECK BEGIN ([a-z][a-z0-9.-]*) "
    rb"(type|definition|state|predicate|init|operation|monitor)\r?\n$"
)
END = re.compile(rb"^% POINTS-CHECK END ([a-z][a-z0-9.-]*)\r?\n$")

SOURCE_MARKERS = [
    ("types.routing-carriers", "type"),
    ("types.transaction-carriers", "type"),
    ("types.bool", "type"),
    ("types.transport", "type"),
    ("definitions.events", "definition"),
    ("types.txn", "type"),
    ("definitions.filesystem", "definition"),
    ("state.txnvars", "state"),
    ("predicate.txnsafety", "predicate"),
    ("predicate.snapshot", "predicate"),
    ("predicate.backup", "predicate"),
    ("predicate.publication", "predicate"),
    ("init.txn", "init"),
    ("effect.frames", "definition"),
    ("effect.append", "definition"),
    ("effect.checkpoint", "definition"),
    ("operation.candidatefailure", "operation"),
    ("operation.createstage", "operation"),
    ("operation.createstagefailure", "operation"),
    ("operation.writestage", "operation"),
    ("operation.writestagefailure", "operation"),
    ("operation.filesyncstage", "operation"),
    ("operation.filesyncstagefailure", "operation"),
    ("operation.closestage", "operation"),
    ("operation.closestagefailure", "operation"),
    ("operation.beginrevalidation", "operation"),
    ("operation.revalidationsuccess", "operation"),
    ("operation.revalidationiofailure", "operation"),
    ("operation.commitabsent", "operation"),
    ("operation.commitabsentfailure", "operation"),
    ("operation.confirmconfigsuccess", "operation"),
    ("operation.confirmconfigfailure", "operation"),
    ("operation.begincleanup", "operation"),
    ("operation.unlinkowned", "operation"),
    ("operation.cleanupalreadyabsent", "operation"),
    ("operation.cleanupunlinkfailed", "operation"),
    ("operation.cleanupinspectionfailed", "operation"),
    ("operation.endcleanupsweep", "operation"),
    ("operation.cleanupsyncsuccess", "operation"),
    ("operation.cleanupsyncfailure", "operation"),
    ("operation.releasesuccess", "operation"),
    ("operation.releasefailure", "operation"),
    ("operation.reportdelivered", "operation"),
    ("operation.reportfailed", "operation"),
    ("operation.finishtransaction", "operation"),
    ("operation.observecancellation", "operation"),
    ("operation.processdeath", "operation"),
    ("operation.powerloss", "operation"),
    ("monitor.types", "monitor"),
    ("monitor.vars", "monitor"),
    ("monitor.init", "monitor"),
    ("monitor.update", "monitor"),
    ("monitor.safety", "monitor"),
]
SOURCE_BLOCKS = [identifier for identifier, _ in SOURCE_MARKERS]

OMITTED_BLOCKS = {
    "types.routing-carriers",
    "init.txn",
    "monitor.init",
    "operation.cleanupalreadyabsent",
}
PROJECTION_BLOCKS = [
    identifier for identifier in SOURCE_BLOCKS if identifier not in OMITTED_BLOCKS
]

ALL_OPERATIONS = """CandidateFailure CreateStage CreateStageFailure WriteStage
WriteStageFailure FileSyncStage FileSyncStageFailure CloseStage
CloseStageFailure BeginRevalidation RevalidationSuccess RevalidationIOFailure
CommitAbsent CommitAbsentFailure ConfirmConfigSuccess ConfirmConfigFailure
BeginCleanup UnlinkOwned CleanupAlreadyAbsent CleanupUnlinkFailed
CleanupInspectionFailed EndCleanupSweep CleanupSyncSuccess CleanupSyncFailure
ReleaseSuccess ReleaseFailure ReportDelivered ReportFailed FinishTransaction
ObserveCancellation ProcessDeath PowerLoss""".split()
EXCLUDED_OPERATIONS = ["CleanupAlreadyAbsent"]
OPERATIONS = [op for op in ALL_OPERATIONS if op not in EXCLUDED_OPERATIONS]

PARAMETERS = {
    "CandidateFailure": None,
    "CreateStage": "p? : Path; id? : Identity; initialImage? : FileImage; delta? : Delta",
    "CreateStageFailure": "p? : Path; id? : Identity",
    "WriteStage": "id? : Identity; image? : FileImage",
    "WriteStageFailure": "id? : Identity",
    "FileSyncStage": "id? : Identity",
    "FileSyncStageFailure": "id? : Identity",
    "CloseStage": "id? : Identity",
    "CloseStageFailure": "id? : Identity",
    "BeginRevalidation": None,
    "RevalidationSuccess": None,
    "RevalidationIOFailure": None,
    "CommitAbsent": "delta? : Delta",
    "CommitAbsentFailure": None,
    "ConfirmConfigSuccess": None,
    "ConfirmConfigFailure": None,
    "BeginCleanup": None,
    "UnlinkOwned": "p? : Path; delta? : Delta",
    "CleanupAlreadyAbsent": "p? : Path",
    "CleanupUnlinkFailed": "p? : Path",
    "CleanupInspectionFailed": "p? : Path",
    "EndCleanupSweep": None,
    "CleanupSyncSuccess": None,
    "CleanupSyncFailure": None,
    "ReleaseSuccess": None,
    "ReleaseFailure": None,
    "ReportDelivered": None,
    "ReportFailed": None,
    "FinishTransaction": None,
    "ObserveCancellation": None,
    "ProcessDeath": None,
    "PowerLoss": (
        "crashNS : Namespace; crashImages : Identity \\pfun FileImage \\\\\n"
        "takeOne, takeTwo, takeThree, takeFour, takeFive, takeSix : Bool \\\\\n"
        "afterOne, afterTwo, afterThree, afterFour, afterFive : Namespace"
    ),
}

TXN_FIELDS = """visibleNS durableNS pendingCount pendingDeltaOne
pendingDeltaTwo pendingDeltaThree pendingDeltaFour pendingDeltaFive
pendingDeltaSix visibleImages syncedImages intendedImages snapshotImages
dirtyChoices stageIDs sealedIDs closeOK published publicationImages owned
cleanupDue cleanupPending retainedResults cleanupNotes configPath backupPath
configStage backupStage candidateID backupIDs expectedConfig conflicts phase
committed configSyncAck cancelled lockHeld backupProgress life reportState
revalidationPassed confirmationAttempted cleanupWork cleanupTried
cleanupSyncAttempted releaseAttempted events inputAccepted writeStarted noOp
namespaceMutated snapshotLinks currentLinks snapshotAccess currentAccess
ownedBackupPublication backupAbsenceConfirmed authorizationPassed
authorizedTransport insecureConsent""".split()

MONITOR_FIELDS = """seen linksInjected accessInjected replacementInjected
cancellationAfterCommit deathKind lastCrashMask preCrashActiveCount
publicationSeen publicationQualified configPublicationSeen
revalidatedAtConfigPublication backupReadyAtConfigPublication replacementPath
replacementIdentity badRevalidation badFilePublication badBackupOrder
badReplacementUnlink badPrematureReport badPostDeathStep badImageCoverage
badFinalImage badRetainedCleanup""".split()

ROUTING_CARRIERS = ["ModelId", "Provider", "Source"]
TRANSACTION_CARRIERS = [
    "JSONPointer",
    "Path",
    "Identity",
    "Owner",
    "Mode",
    "ByteString",
    "Delta",
    "FileImage",
]
ALL_CARRIERS = ROUTING_CARRIERS + TRANSACTION_CARRIERS

CARDINALITIES = {
    "JSONPointer": 1,
    "Path": 4,
    "Identity": 1,
    "Owner": 1,
    "Mode": 1,
    "ByteString": 3,
    "Delta": 4,
    "FileImage": 6,
}

FILESYSTEM_CONSTANTS = """deltaRemove deltaPut emptyBytes bytePrefix
imageBytes imageMode imageOwner imageState""".split()
FILESYSTEM_DEFINITIONS = ["applyDelta", "refs"]

SCOPE = rb"""
\begin{axdef}
 ptrConflict : JSONPointer \\
 pConfig, pBackup, pConfigStage, pBackupStage : Path \\
 idCandidate : Identity; ownerUser : Owner; mode0600 : Mode \\
 emptyA, prefixBytes, candidateBytes : ByteString \\
 dIdle, dCreateC, dLinkC, dDropC : Delta \\
 imagePartialEmpty, imageCompleteEmpty : FileImage \\
 imagePartialPrefix, imageCompletePrefix : FileImage \\
 imagePartialCandidate, imageCompleteCandidate : FileImage
\where
 JSONPointer = \{ ptrConflict \} \land \# JSONPointer = 1 \\
 Path = \{ pConfig, pBackup, pConfigStage, pBackupStage \} \\
 Identity = \{ idCandidate \} \land Owner = \{ ownerUser \} \land Mode = \{ mode0600 \} \\
 ByteString = \{ emptyA, prefixBytes, candidateBytes \} \\
 Delta = \{ dIdle, dCreateC, dLinkC, dDropC \} \\
 FileImage = \{ imagePartialEmpty, imageCompleteEmpty, imagePartialPrefix,
 imageCompletePrefix, imagePartialCandidate, imageCompleteCandidate \} \\
 \# Path = 4 \land \# Identity = 1 \land
 \# Owner = 1 \land \# Mode = 1 \\
 \# ByteString = 3 \land \# Delta = 4 \land \# FileImage = 6
\end{axdef}
"""

PRIMITIVES = rb""" deltaRemove == \{ dIdle \mapsto \emptyset,
  dCreateC \mapsto \emptyset,
  dLinkC \mapsto \emptyset,
  dDropC \mapsto \{ pConfigStage \} \} \\
 deltaPut == \{ dIdle \mapsto \emptyset,
  dCreateC \mapsto \{ pConfigStage \mapsto file~idCandidate \},
  dLinkC \mapsto \{ pConfig \mapsto file~idCandidate \},
  dDropC \mapsto \emptyset \} \\
 emptyBytes == emptyA \\
 bytePrefix == \{ emptyA \mapsto emptyA,
  emptyA \mapsto prefixBytes,
  emptyA \mapsto candidateBytes,
  prefixBytes \mapsto prefixBytes,
  prefixBytes \mapsto candidateBytes,
  candidateBytes \mapsto candidateBytes \} \\
 imageBytes == \{
  imagePartialEmpty \mapsto emptyA,
  imageCompleteEmpty \mapsto emptyA,
  imagePartialPrefix \mapsto prefixBytes,
  imageCompletePrefix \mapsto prefixBytes,
  imagePartialCandidate \mapsto candidateBytes,
  imageCompleteCandidate \mapsto candidateBytes \} \\
 imageMode == \{
  imagePartialEmpty \mapsto mode0600,
  imageCompleteEmpty \mapsto mode0600,
  imagePartialPrefix \mapsto mode0600,
  imageCompletePrefix \mapsto mode0600,
  imagePartialCandidate \mapsto mode0600,
  imageCompleteCandidate \mapsto mode0600 \} \\
 imageOwner == \{
  imagePartialEmpty \mapsto ownerUser,
  imageCompleteEmpty \mapsto ownerUser,
  imagePartialPrefix \mapsto ownerUser,
  imageCompletePrefix \mapsto ownerUser,
  imagePartialCandidate \mapsto ownerUser,
  imageCompleteCandidate \mapsto ownerUser \} \\
 imageState == \{
  imagePartialEmpty \mapsto partial,
  imageCompleteEmpty \mapsto complete,
  imagePartialPrefix \mapsto partial,
  imageCompletePrefix \mapsto complete,
  imagePartialCandidate \mapsto partial,
  imageCompleteCandidate \mapsto complete \} \\
"""

SCENARIO_ASSIGNMENTS = rb""" configPath'=pConfig \land backupPath'=pBackup \land
 configStage'=pConfigStage \land backupStage'=pBackupStage \\
 candidateID'=idCandidate \land backupIDs'=\emptyset \land
 expectedConfig'=\emptyset \land conflicts'=\emptyset \\
 visibleNS'=\emptyset \land durableNS'=\emptyset \\
 visibleImages'=\emptyset \land syncedImages'=\emptyset \land dirtyChoices'=\emptyset \\
 intendedImages'=\{idCandidate\mapsto imageCompleteCandidate\} \land
 snapshotImages'=\emptyset \\
 snapshotLinks'=\emptyset \land currentLinks'=\emptyset \land
 snapshotAccess'=\emptyset \land currentAccess'=\emptyset \\
 authorizationPassed'=yes \land authorizedTransport'=\{httpsTransport\} \land
 insecureConsent'=no \\
 pendingDeltaOne'=dIdle \land pendingDeltaTwo'=dIdle \land
 pendingDeltaThree'=dIdle \land pendingDeltaFour'=dIdle \land
 pendingDeltaFive'=dIdle \land pendingDeltaSix'=dIdle"""

STATE = rb"""
\begin{schema}{State}
 TxnVars \\
 CheckMonitor
\end{schema}
"""

INVARIANT = rb"""
\begin{schema}{Invariant}
 State
\where
 ScenarioAFilesystemSemantics \\
 TxnSafety \\
 MonitorSafety
\end{schema}
"""


def marked(data: bytes) -> tuple[dict[str, bytes], list[tuple[str, str]]]:
    found: dict[str, bytes] = {}
    markers: list[tuple[str, str]] = []
    active: str | None = None
    body: list[bytes] = []
    for line_number, line in enumerate(data.splitlines(keepends=True), 1):
        begin, end = BEGIN.fullmatch(line), END.fullmatch(line)
        if b"POINTS-CHECK" in line:
            require(
                begin is not None or end is not None,
                f"malformed POINTS-CHECK marker at line {line_number}",
            )
        if begin:
            require(active is None, f"nested source block at line {line_number}")
            identifier = begin.group(1).decode("ascii")
            kind = begin.group(2).decode("ascii")
            require(identifier not in found, f"duplicate source block {identifier}")
            markers.append((identifier, kind))
            active, body = identifier, []
        elif end:
            require(active is not None, f"unmatched source end at line {line_number}")
            identifier = end.group(1).decode("ascii")
            require(
                identifier == active, f"source end {identifier} does not match {active}"
            )
            found[active] = b"".join(body)
            active = None
        elif active is not None:
            body.append(line)
    require(active is None, f"unterminated source block {active}")
    return found, markers


def schema_bytes(data: bytes, name: str) -> bytes:
    start = f"\\begin{{schema}}{{{name}}}\n".encode()
    end = b"\\end{schema}\n"
    require(data.count(start) == 1, f"expected exactly one {name} schema")
    first = data.index(start)
    last = data.index(end, first) + len(end)
    return data[first:last]


def schema_declarations(data: bytes, name: str) -> bytes:
    schema = schema_bytes(data, name)
    body = schema.split(b"\n", 1)[1].rsplit(b"\\end{schema}\n", 1)[0]
    return body.split(b"\\where", 1)[0]


def schema_predicate(data: bytes, name: str) -> bytes:
    schema = schema_bytes(data, name)
    body = schema.split(b"\n", 1)[1].rsplit(b"\\end{schema}\n", 1)[0]
    parts = body.split(b"\\where", 1)
    require(len(parts) == 2 and parts[1].startswith(b"\n"), f"{name} has no predicate")
    return parts[1][1:]


def declared_fields(block: bytes, name: str) -> list[str]:
    declarations = schema_declarations(block, name)
    answer: list[str] = []
    for declaration in declarations.split(b"\\\\"):
        if b":" not in declaration:
            continue
        left = declaration.split(b":", 1)[0]
        answer.extend(
            item.strip().decode() for item in left.split(b",") if item.strip()
        )
    return answer


def carrier_inventory(block: bytes, identifier: str) -> list[str]:
    parsed = re.fullmatch(
        rb"\\begin\{zed\}\r?\n[ \t]*\[([A-Za-z0-9_, \t\r\n]+)\]\r?\n"
        rb"\\end\{zed\}\r?\n",
        block,
    )
    require(parsed is not None, f"{identifier} has an unexpected carrier shape")
    return [
        name.decode() for name in re.findall(rb"[A-Za-z][A-Za-z0-9]*", parsed.group(1))
    ]


def declared_given_sets(data: bytes) -> list[str]:
    answer: list[str] = []
    for paragraph in re.findall(
        rb"\\begin\{zed\}\r?\n(.*?)\\end\{zed\}\r?\n", data, re.S
    ):
        declaration = re.fullmatch(
            rb"[ \t]*\[([A-Za-z0-9_, \t\r\n]+)\]\r?\n", paragraph
        )
        if declaration is not None:
            answer.extend(
                name.decode()
                for name in re.findall(rb"[A-Za-z][A-Za-z0-9]*", declaration.group(1))
            )
    return answer


def initializer_predicate(block: bytes, name: str, declaration: str) -> bytes:
    header = f"\\begin{{schema}}{{{name}}}\n\t{declaration}\n\t\\where\n".encode()
    end = b"\n\\end{schema}\n"
    require(
        block.startswith(header) and block.endswith(end),
        f"malformed {name} initializer",
    )
    require(block.count(b"\\begin{schema}") == 1, f"extra schema in {name} block")
    predicate = block[len(header) : -len(end)]
    require(bool(predicate), f"empty {name} initializer")
    return predicate


def parse_filesystem(block: bytes) -> dict[str, object]:
    parsed = re.fullmatch(
        rb"\\begin\{axdef\}\n(.*?)\n\\end\{axdef\}\n\n"
        rb"\\begin\{zed\}\n(.*?)\n\\end\{zed\}\n",
        block,
        re.S,
    )
    require(parsed is not None, "filesystem block has an unexpected shape")
    axdef_body, definitions = parsed.groups()
    parts = axdef_body.split(b"\n\t\\where\n", 1)
    require(len(parts) == 2, "filesystem axdef has no exact where separator")
    declaration_bytes, axioms = parts
    declarations: list[tuple[bytes, bytes]] = []
    for line in declaration_bytes.splitlines():
        declaration = re.fullmatch(rb"\t([A-Za-z]+) : (.*?)(?: \\\\)?", line)
        require(declaration is not None, f"malformed filesystem declaration: {line!r}")
        declarations.append(declaration.groups())
    names = [name.decode() for name, _ in declarations]
    require(names == FILESYSTEM_CONSTANTS, "filesystem primitive inventory changed")
    require(
        len(re.findall(rb"(?m)^\t\\forall ", axioms)) == 6,
        "expected six filesystem axioms",
    )
    definition_names = [
        name.decode()
        for name in re.findall(rb"(?m)^\t([A-Za-z]+)[ \t]*==", definitions)
    ]
    require(
        definition_names == FILESYSTEM_DEFINITIONS,
        "filesystem definition inventory changed",
    )
    return {
        "declarations": declarations,
        "axioms": axioms,
        "definitions": definitions,
    }


def filesystem_definitions(filesystem: dict[str, object]) -> bytes:
    definitions = filesystem["definitions"]
    require(isinstance(definitions, bytes), "internal filesystem definitions error")
    rendered = b"\\begin{zed}\n" + PRIMITIVES + definitions + b"\n\\end{zed}\n"
    found = [
        name.decode()
        for name in re.findall(rb"(?m)^[ \t]*([A-Za-z]+)[ \t]*==", rendered)
    ]
    require(
        found == FILESYSTEM_CONSTANTS + FILESYSTEM_DEFINITIONS,
        "generated filesystem definition inventory changed",
    )
    return rendered


def filesystem_semantics(filesystem: dict[str, object]) -> bytes:
    declarations = filesystem["declarations"]
    axioms = filesystem["axioms"]
    require(
        isinstance(declarations, list) and isinstance(axioms, bytes),
        "internal filesystem error",
    )
    memberships = b" \\\\\n".join(
        b" " + name + b" \\in " + type_expression
        for name, type_expression in declarations
    )
    return (
        b"\\begin{schema}{ScenarioAFilesystemSemantics}\n TxnVars\n\\where\n"
        + memberships
        + b" \\\\\n"
        + axioms
        + b"\n\\end{schema}\n"
    )


def validate_source(raw: bytes) -> tuple[dict[str, bytes], bytes, bytes]:
    blocks, markers = marked(raw)
    require(
        markers == SOURCE_MARKERS,
        "source marker identifiers, kinds, or order changed",
    )
    require(
        carrier_inventory(blocks["types.routing-carriers"], "types.routing-carriers")
        == ROUTING_CARRIERS,
        "routing carrier inventory changed",
    )
    require(
        carrier_inventory(
            blocks["types.transaction-carriers"], "types.transaction-carriers"
        )
        == TRANSACTION_CARRIERS,
        "transaction carrier inventory changed",
    )
    declarations = declared_given_sets(raw)
    require(
        all(declarations.count(name) == 1 for name in ALL_CARRIERS),
        "authoritative carrier declarations are not unique",
    )
    require(len(OPERATIONS) == 31, "Scenario A must export exactly 31 operations")
    require(
        set(PARAMETERS) == set(ALL_OPERATIONS),
        "operation signature table is incomplete",
    )
    for operation in ALL_OPERATIONS:
        block = blocks["operation." + operation.lower()]
        marker = f"\\begin{{schema}}{{{operation}}}".encode()
        require(block.count(marker) == 1, f"operation block {operation} changed shape")
    require(
        declared_fields(blocks["state.txnvars"], "TxnVars") == TXN_FIELDS,
        "TxnVars inventory changed",
    )
    require(
        declared_fields(blocks["monitor.vars"], "CheckMonitor") == MONITOR_FIELDS,
        "CheckMonitor inventory changed",
    )
    require(
        len(TXN_FIELDS) == 60 and len(MONITOR_FIELDS) == 24,
        "persistent field count is not 84",
    )
    filesystem = parse_filesystem(blocks["definitions.filesystem"])
    observed = [
        (name.decode(), int(size))
        for name, size in re.findall(rb"\\# ([A-Za-z]+) = ([0-9]+)", SCOPE)
    ]
    require(observed == list(CARDINALITIES.items()), "Scenario A cardinalities changed")
    txn_init = initializer_predicate(blocks["init.txn"], "TxnInit", "TxnVars'")
    monitor_init = initializer_predicate(
        blocks["monitor.init"], "MonitorInit", "CheckMonitor'"
    )
    for operation in ("CreateStage", "CommitAbsent", "UnlinkOwned"):
        declarations = schema_declarations(
            blocks["operation." + operation.lower()], operation
        )
        require(
            b"\tAppendPendingDelta \\\\\n" in declarations,
            f"{operation} lost AppendPendingDelta",
        )
    for operation in ("ConfirmConfigSuccess", "CleanupSyncSuccess"):
        declarations = schema_declarations(
            blocks["operation." + operation.lower()], operation
        )
        require(
            b"\tDirectoryCheckpoint" in declarations,
            f"{operation} lost DirectoryCheckpoint",
        )
    # Materialize these here so malformed source fails before any output write.
    filesystem_definitions(filesystem)
    filesystem_semantics(filesystem)
    return blocks, txn_init, monitor_init


def render_init(txn_init: bytes, monitor_init: bytes) -> bytes:
    return (
        b"\\begin{schema}{Init}\n State'\n\\where\n"
        + txn_init
        + b" \\\\\n"
        + monitor_init
        + b" \\\\\n"
        + SCENARIO_ASSIGNMENTS
        + b"\n\\end{schema}\n"
    )


def wrappers() -> bytes:
    answer: list[bytes] = []
    cleanup_operations = {
        "UnlinkOwned",
        "CleanupAlreadyAbsent",
        "CleanupUnlinkFailed",
        "CleanupInspectionFailed",
    }
    for operation in OPERATIONS:
        path = "\\{p?\\}" if operation in cleanup_operations else "\\emptyset"
        if operation == "PowerLoss":
            mask = (
                "\\{ i : SlotIndex | "
                "(i=1 \\land takeOne=yes) \\lor (i=2 \\land takeTwo=yes) \\lor "
                "(i=3 \\land takeThree=yes) \\lor (i=4 \\land takeFour=yes) \\lor "
                "(i=5 \\land takeFive=yes) \\lor (i=6 \\land takeSix=yes) @ i \\}"
            )
        else:
            mask = "\\emptyset"
        answer.append(
            (
                f"\\begin{{schema}}{{Check{operation}}}\n"
                f"{operation} \\\\\nMonitorUpdate\n\\where\n"
                f"monitorOperation=op{operation} \\land \\\\\n"
                f"monitorPath={path} \\land \\\\\n"
                f"monitorCrashMask={mask}\n"
                "\\end{schema}\n\n"
            ).encode()
        )
    return b"".join(answer)


def render_model(
    blocks: dict[str, bytes], txn_init: bytes, monitor_init: bytes
) -> tuple[bytes, dict[str, object]]:
    filesystem = parse_filesystem(blocks["definitions.filesystem"])
    definitions = filesystem_definitions(filesystem)
    semantics = filesystem_semantics(filesystem)
    payload: list[bytes] = []
    for identifier in PROJECTION_BLOCKS:
        if identifier == "definitions.filesystem":
            payload.extend([SCOPE, definitions])
        else:
            payload.append(blocks[identifier])
            if identifier == "state.txnvars":
                payload.append(semantics)
    wrapper_payload = wrappers()
    result = (
        b"\\documentclass{article}\n\\usepackage{fuzz}\n\\begin{document}\n"
        + b"".join(payload)
        + STATE
        + render_init(txn_init, monitor_init)
        + INVARIANT
        + wrapper_payload
        + b"\n\\end{document}\n"
    )
    validate_model(result, blocks, txn_init, monitor_init, definitions, semantics)
    details = {
        "source_blocks": SOURCE_BLOCKS,
        "projection_blocks": PROJECTION_BLOCKS,
        "omitted_projection_blocks": [
            block for block in SOURCE_BLOCKS if block in OMITTED_BLOCKS
        ],
        "copied_projection_blocks": [
            block for block in PROJECTION_BLOCKS if block != "definitions.filesystem"
        ],
        "block_sha256": {name: sha256(blocks[name]) for name in SOURCE_BLOCKS},
        "initializer_predicate_sha256": {
            "TxnInit": sha256(txn_init),
            "MonitorInit": sha256(monitor_init),
        },
        "filesystem_transform": "scenario-a-finite-expression-definitions-v3",
        "filesystem_definitions_sha256": sha256(definitions),
        "filesystem_semantics_sha256": sha256(semantics),
        "exported_wrappers": ["Check" + operation for operation in OPERATIONS],
        "excluded_wrappers": ["Check" + operation for operation in EXCLUDED_OPERATIONS],
        "scenario_cardinalities": CARDINALITIES,
        "txn_fields": TXN_FIELDS,
        "monitor_fields": MONITOR_FIELDS,
        "persistent_field_count": len(TXN_FIELDS) + len(MONITOR_FIELDS),
        "pending_slots": 6,
    }
    return result, details


def validate_model(
    data: bytes,
    blocks: dict[str, bytes],
    txn_init: bytes,
    monitor_init: bytes,
    definitions: bytes,
    semantics: bytes,
) -> None:
    require(data.count(SCOPE) == 1, "generated scope is not unique")
    require(
        data.count(definitions) == 1, "generated filesystem definitions are not unique"
    )
    require(data.count(semantics) == 1, "generated filesystem semantics are not unique")
    require(
        blocks["definitions.filesystem"] not in data,
        "abstract filesystem axdef leaked into projection",
    )
    require(
        blocks["operation.cleanupalreadyabsent"] not in data,
        "excluded cleanup operation leaked into projection",
    )
    require(
        data.count(blocks["types.transaction-carriers"]) == 1,
        "transaction carrier block is not copied exactly once",
    )
    require(
        b"JSONPointer = \\{ ptrConflict \\} \\land \\# JSONPointer = 1" in data,
        "Scenario A JSONPointer scope changed",
    )
    for forbidden in ROUTING_CARRIERS + ["solA", "providerA", "sourceA"]:
        token = re.escape(forbidden.encode())
        require(
            re.search(rb"(?<![A-Za-z0-9])" + token + rb"(?![A-Za-z0-9])", data) is None,
            f"unused routing token {forbidden} leaked into projection",
        )
    for identifier in PROJECTION_BLOCKS:
        if identifier != "definitions.filesystem":
            require(
                data.count(blocks[identifier]) == 1,
                f"copied block {identifier} is not byte exact",
            )
    require(
        schema_declarations(data, "State") == b" TxnVars \\\\\n CheckMonitor\n",
        "State topology changed",
    )
    require(schema_declarations(data, "Init") == b" State'\n", "Init topology changed")
    require(
        data.count(txn_init) == 1 and data.count(monitor_init) == 1,
        "initializer predicate was not copied exactly",
    )
    require(
        schema_declarations(data, "Invariant") == b" State\n",
        "Invariant declaration changed",
    )
    require(
        schema_predicate(data, "Invariant")
        == b" ScenarioAFilesystemSemantics \\\\\n TxnSafety \\\\\n MonitorSafety\n",
        "full invariant topology changed",
    )
    check_schemas = re.findall(rb"\\begin\{schema\}\{(Check[A-Za-z]+)\}\n", data)
    expected = [b"CheckMonitor"] + [
        ("Check" + operation).encode() for operation in OPERATIONS
    ]
    require(
        check_schemas == expected, "generated Check schema inventory or order changed"
    )
    require(
        b"CheckCleanupAlreadyAbsent" not in check_schemas,
        "excluded wrapper was generated",
    )
    for operation in OPERATIONS:
        wrapper = schema_bytes(data, "Check" + operation)
        require(b"\\Delta State" not in wrapper, f"Check{operation} promotes State")
        require(
            b"\\exists" not in wrapper, f"Check{operation} hides operation parameters"
        )
    for name in FILESYSTEM_CONSTANTS + FILESYSTEM_DEFINITIONS:
        encoded = re.escape(name.encode())
        require(
            len(re.findall(rb"(?m)^[ \t]*" + encoded + rb"[ \t]*==", data)) == 1,
            f"generated {name} definition is not unique",
        )
        require(
            not re.search(rb"(?m)^[ \t]*" + encoded + rb"[ \t]*:", data),
            f"{name} remained abstract",
        )
    require(b"\\begin{schema}{Scope}" not in data, "ignored Scope schema is forbidden")
    require(b"\\prozignore" not in data, "ignored ProZ predicate is forbidden")


def generate(args: argparse.Namespace) -> None:
    source = Path(args.source)
    output = Path(args.output)
    manifest_path = Path(args.manifest)
    raw = source.read_bytes()
    blocks, txn_init, monitor_init = validate_source(raw)
    model, details = render_model(blocks, txn_init, monitor_init)
    generator = Path(__file__).read_bytes()
    manifest = {
        "format_version": 1,
        "scenario": "A-smoke",
        "scope": "absent-config accepted-write initialization and one successful lifecycle witness",
        "source_sha256": sha256(raw),
        "generator_sha256": sha256(generator),
        "generated_model_sha256": sha256(model),
        "transformation": (
            "authoritative routing carriers omitted; marked transaction blocks "
            "copied byte-for-byte; "
            "abstract filesystem primitives replaced by the fixed Scenario A "
            "valuation; authoritative applyDelta/refs and six filesystem axioms "
            "preserved; generated State/Init/Invariant and Check wrappers only"
        ),
        "bounds": {
            "TIME_OUT": 10000,
            "MAX_INITIALISATIONS": 100000,
            "MAX_OPERATIONS": 100000,
            "global_time_out": 180000,
        },
        **details,
    }
    encoded_manifest = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    # All validation and deterministic second rendering precede writes.
    second_model, second_details = render_model(blocks, txn_init, monitor_init)
    require(
        model == second_model and details == second_details,
        "generation is nondeterministic",
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(model)
    manifest_path.write_bytes(encoded_manifest)
    require(output.read_bytes() == model, "generated model write was incomplete")
    require(
        manifest_path.read_bytes() == encoded_manifest, "manifest write was incomplete"
    )


FATAL_CHECKER_PATTERNS = re.compile(
    r"model_check_incomplete|Not all states|TIME OUT|global timeout|"
    r"Abnormal termination|Loading Specification Failed|Unexpected error occurred|"
    r"setup_constants_fails|unknown constraint|invariant_violated:[1-9]",
    re.IGNORECASE,
)

ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")

STATE_COUNT_PATTERNS = (
    re.compile(r"States analysed:\s*([0-9]+)"),
    re.compile(r"(?<![A-Za-z0-9_])STATES\s*\(\s*([0-9]+)\s*\)"),
)
TRANSITION_COUNT_PATTERNS = (
    re.compile(r"Transitions fired:\s*([0-9]+)"),
    re.compile(r"(?<![A-Za-z0-9_])TOTAL_TRANSITIONS\s*,\s*([0-9]+)"),
)


def positive_counts(
    text: str, label: str, patterns: tuple[re.Pattern[str], ...]
) -> list[int]:
    """Require every recognized legacy or native counter to be positive."""
    counts = [
        int(match.group(1)) for pattern in patterns for match in pattern.finditer(text)
    ]
    require(counts, f"missing {label} count")
    require(all(count > 0 for count in counts), f"{label} count is zero")
    return counts


def validate_checker_diagnostics(output: str, phase: str) -> None:
    """Reject checker failures, allowing only ProB's expected goal category."""
    clean = ANSI_ESCAPE.sub("", output)
    require(
        not FATAL_CHECKER_PATTERNS.search(clean),
        "checker reported an error, truncation, or invariant violation",
    )
    error_totals = [
        int(total) for total in re.findall(r"Total Errors:\s*([0-9]+)", clean)
    ]
    if phase == "init":
        require(
            "COUNTER EXAMPLE FOUND" not in clean,
            "initialization reported a counterexample",
        )
        require(
            not any(total > 0 for total in error_totals),
            "initialization reported checker errors",
        )
        return

    require(
        "Found GOAL" in clean
        and re.search(r"(?m)^\s*!?\s*goal_found\s*$", clean) is not None,
        "lifecycle goal was not explicitly found",
    )
    require(
        all(total <= 1 for total in error_totals),
        "lifecycle reported errors beyond the expected goal_found category",
    )
    for diagnostic in re.findall(r"(?m)^\s*!\s*(.*?)\s*$", clean):
        if re.fullmatch(r"\*{3}\s*error occurred\s*\*{3}", diagnostic, re.I):
            continue
        if diagnostic == "goal_found":
            continue
        if re.fullmatch(
            r"Total Errors:\s*[01](?:\s*,\s*Warnings:\s*[0-9]+)?", diagnostic
        ):
            continue
        raise ValidationError(
            "lifecycle reported a non-goal checker error: " + diagnostic
        )


def persistent_valuations(dot: str) -> list[dict[str, str]]:
    """Return DOT nodes that assign every persistent field.

    ProB prints a function-valued variable as one assignment per maplet, so a
    populated map appears as ``owned(Path3) = idCandidate,owned(Path4) =
    idCandidate``. Those repeats are one field, not a malformed node: requiring
    a single occurrence of every name silently discards every state in which
    such a map is non-empty, which is every state after the transaction starts
    allocating. An applied occurrence may therefore repeat and its maplets are
    rejoined; a bare occurrence must still appear exactly once.
    """
    all_fields = TXN_FIELDS + MONITOR_FIELDS
    field_names = "|".join(re.escape(field) for field in all_fields)
    assignment_start = re.compile(
        rf"(?m)(?:^|[\n,])\s*({field_names})(\([^()\n]*\))?\s*=\s*"
    )
    labels = re.findall(r'label\s*=\s*"((?:\\.|[^"\\])*)"', dot, re.S)
    valuations: list[dict[str, str]] = []
    for encoded_label in labels:
        # Graphviz records label line breaks as literal backslash escapes.
        label = re.sub(r"\\[nlr]", "\n", encoded_label)
        assignments = list(assignment_start.finditer(label))
        bare = [
            assignment.group(1)
            for assignment in assignments
            if assignment.group(2) is None
        ]
        if any(bare.count(field) > 1 for field in all_fields):
            continue
        valuation: dict[str, str] = {}
        for index, assignment in enumerate(assignments):
            value_end = (
                assignments[index + 1].start()
                if index + 1 < len(assignments)
                else len(label)
            )
            field = assignment.group(1)
            value = label[assignment.end() : value_end].strip().rstrip(",")
            if assignment.group(2) is None:
                valuation[field] = value
            else:
                maplet = f"{assignment.group(2)}={value}"
                existing = valuation.get(field)
                valuation[field] = f"{existing},{maplet}" if existing else maplet
        if len(valuation) == len(all_fields):
            valuations.append(valuation)
    return valuations


def validate_checker(args: argparse.Namespace) -> None:
    output = Path(args.checker_output).read_text(errors="replace")
    dot = Path(args.dot).read_text(errors="replace")
    validate_checker_diagnostics(output, args.phase)
    require("Promoting Schema" not in output, "ProZ promoted a helper schema")
    loaded = re.findall(r"^Z operation: ([A-Za-z]+)(?:\([^\n]*\))?$", output, re.M)
    expected = ["Check" + operation for operation in OPERATIONS]
    require(
        loaded == expected,
        "actual ProZ operation inventory is not the exact 31 wrappers",
    )
    positive_counts(output, "States analysed", STATE_COUNT_PATTERNS)
    complete_valuations = persistent_valuations(dot)
    require(
        bool(complete_valuations),
        "DOT evidence has no node assigning all 84 persistent fields exactly once",
    )
    if args.phase == "init":
        valuation = complete_valuations[-1]
        for slot in (
            "pendingDeltaOne",
            "pendingDeltaTwo",
            "pendingDeltaThree",
            "pendingDeltaFour",
            "pendingDeltaFive",
            "pendingDeltaSix",
        ):
            require(
                valuation[slot] == "dIdle",
                f"initial {slot} is not idle",
            )
        require(
            valuation["life"] == "running" and valuation["phase"] == "staging",
            "DOT lacks the concrete initial control state",
        )
        return
    positive_counts(output, "Transitions fired", TRANSITION_COUNT_PATTERNS)
    trace = Path(args.trace).read_text(errors="replace")
    required = [
        "CheckCreateStage",
        "CheckWriteStage",
        "CheckFileSyncStage",
        "CheckCloseStage",
        "CheckBeginRevalidation",
        "CheckRevalidationSuccess",
        "CheckCommitAbsent",
        "CheckConfirmConfigSuccess",
        "CheckBeginCleanup",
        "CheckUnlinkOwned",
        "CheckEndCleanupSweep",
        "CheckCleanupSyncSuccess",
        "CheckReleaseSuccess",
        "CheckReportDelivered",
        "CheckFinishTransaction",
    ]
    positions = []
    for operation in required:
        position = trace.find(operation)
        require(position >= 0, f"lifecycle trace lacks {operation}")
        positions.append(position)
    require(
        positions == sorted(positions) and len(set(positions)) == len(positions),
        "lifecycle operation order changed",
    )
    endpoint = {
        "life": "ended",
        "phase": "finished",
        "reportState": "reportDelivered",
        "committed": "yes",
        "configSyncAck": "yes",
        "lockHeld": "no",
    }
    require(
        any(
            all(valuation[field] == value for field, value in endpoint.items())
            for valuation in complete_valuations
        ),
        "lifecycle DOT has no complete node with the required endpoint",
    )


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    subparsers = result.add_subparsers(dest="command", required=True)
    generation = subparsers.add_parser("generate")
    generation.add_argument("--source", required=True)
    generation.add_argument("--output", required=True)
    generation.add_argument("--manifest", required=True)
    generation.set_defaults(func=generate)
    checker = subparsers.add_parser("validate")
    checker.add_argument("--phase", choices=("init", "lifecycle"), required=True)
    checker.add_argument("--checker-output", required=True)
    checker.add_argument("--dot", required=True)
    checker.add_argument("--trace")
    checker.set_defaults(func=validate_checker)
    return result


def main() -> int:
    try:
        args = parser().parse_args()
        if args.command == "validate" and args.phase == "lifecycle":
            require(bool(args.trace), "lifecycle validation requires --trace")
        status = args.func(args)
        return status if isinstance(status, int) else 0
    except (OSError, ValueError, ValidationError, json.JSONDecodeError) as error:
        print(f"spec-prob-a: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
