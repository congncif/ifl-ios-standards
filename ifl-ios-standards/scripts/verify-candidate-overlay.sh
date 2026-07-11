#!/bin/bash

set -u
set -o pipefail

readonly EXIT_PASSED=0
readonly EXIT_CONFORMANCE=1
readonly EXIT_INVALID_INPUT=2
readonly EXIT_BLOCKED_ENVIRONMENT=3
readonly EXIT_INTERNAL_ERROR=4
readonly EXIT_INTEGRITY=5

diagnose() {
  printf 'candidate-overlay-verifier: %s\n' "$1" >&2
}

fail() {
  diagnose "$1"
  exit "$2"
}

if [ "$#" -ne 1 ]; then
  fail 'usage: verify-candidate-overlay.sh 2a|2b|2c' "$EXIT_INVALID_INPUT"
fi

CHECKPOINT="$1"
readonly CHECKPOINT

case "$CHECKPOINT" in
  2a)
    FOCUSED_FILTER='IFLContractsTests\.(CandidateOverlayV1CompatibilityTests|CandidateOverlaySchemaParityTests|CandidateOverlayTransformContractTests|CanonSchemaFileTests|CanonSchemaContractTests|CanonSchemaLexicalTests|CanonicalRelativePathParityTests|CanonActivationContractTests)'
    PROTECTED_SYMBOL='CanonActivationApprovalInput'
    expected_paths=(
      'ifl-ios-standards/scripts/verify-candidate-overlay.sh'
      'ifl-ios-standards/standards/canon/schemas/v1/activation-receipt.schema.json'
      'ifl-ios-standards/standards/canon/schemas/v1/candidate-component-bundle.schema.json'
      'ifl-ios-standards/standards/canon/schemas/v1/candidate-overlay.schema.json'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLContracts/CandidateComponentBundle.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLContracts/CandidateOverlayManifest.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLContracts/CandidateOverlayTransformDescriptor.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLContracts/CandidatePublicationAuthorityMap.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLContracts/CanonActivationApprovalInput.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLContracts/CanonActivationReceipt.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLContracts/ReviewApprovalReference.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLContractsTests/CandidateOverlaySchemaParityTests.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLContractsTests/CandidateOverlayTransformContractTests.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLContractsTests/CandidateOverlayV1CompatibilityTests.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLContractsTests/CanonActivationContractTests.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLContractsTests/CanonSchemaContractTests.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLContractsTests/CanonSchemaFileTests.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLContractsTests/CanonSchemaLexicalTests.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLContractsTests/CanonicalRelativePathParityTests.swift'
      'ifl-ios-standards/verification/fixtures/canon/candidate-overlay/contracts/amended-v1/accepted-overlay.json'
      'ifl-ios-standards/verification/fixtures/canon/candidate-overlay/contracts/amended-v1/candidate-overlay-transform-descriptor.json'
      'ifl-ios-standards/verification/fixtures/canon/candidate-overlay/contracts/amended-v1/candidate-publication-authority-map.json'
      'ifl-ios-standards/verification/fixtures/canon/candidate-overlay/contracts/amended-v1/component-core.bundle.json'
      'ifl-ios-standards/verification/fixtures/canon/candidate-overlay/contracts/pre-amendment-v1/accepted-overlay.json'
      'ifl-ios-standards/verification/fixtures/canon/candidate-overlay/contracts/pre-amendment-v1/candidate-overlay.schema.json'
      'ifl-ios-standards/verification/fixtures/canon/candidate-overlay/contracts/pre-amendment-v1/provenance.json'
    )
    ;;
  2b)
    FOCUSED_FILTER='IFLCanonTests\.(CandidateOverlayRetainedSourceTests|CandidateOverlayValidatorTests|CandidateOverlayPublicSurfaceTests)|IFLVerificationTests\.CandidateOverlayRootLocatorTests'
    PROTECTED_SYMBOL='ValidatedCandidateOverlay'
    expected_paths=(
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/BasePluginSnapshotEvidence.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/CandidateOverlayValidator.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/CandidateTreeCapture.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/CanonDescriptorReader.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/CanonRootAnchor.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/CanonSnapshot.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/CanonSnapshotEvidence.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/FileCanonRepository.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/RetainedPluginRootAnchor.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/ValidatedCandidateOverlay.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLVerification/VerificationRootLocator.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLCanonTests/CandidateOverlayPublicSurfaceTests.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLCanonTests/CandidateOverlayRetainedSourceTests.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLCanonTests/CandidateOverlayValidatorTests.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLCanonTests/Support/CandidateOverlayFixture.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLVerificationTests/CandidateOverlayRootLocatorTests.swift'
    )
    ;;
  2c)
    FOCUSED_FILTER='IFLCanonTests\.(CandidateOverlayResolverTests|ResolvedCandidateActivationPublicSurfaceTests|CandidateOverlayValidatorTests)'
    PROTECTED_SYMBOL='ResolvedCandidateActivation'
    expected_paths=(
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/CandidateActivationTransform.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/CandidateOverlayResolver.swift'
      'ifl-ios-standards/tools/ifl-tooling/Sources/IFLCanon/ResolvedCandidateActivation.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLCanonTests/CandidateOverlayResolverTests.swift'
      'ifl-ios-standards/tools/ifl-tooling/Tests/IFLCanonTests/ResolvedCandidateActivationPublicSurfaceTests.swift'
    )
    ;;
  *)
    fail 'usage: verify-candidate-overlay.sh 2a|2b|2c' "$EXIT_INVALID_INPUT"
    ;;
esac
readonly FOCUSED_FILTER
readonly PROTECTED_SYMBOL

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)" \
  || fail 'could not resolve verifier script directory' "$EXIT_BLOCKED_ENVIRONMENT"
readonly SCRIPT_DIR
PLUGIN_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)" \
  || fail 'could not resolve physical plugin root' "$EXIT_BLOCKED_ENVIRONMENT"
readonly PLUGIN_ROOT
repo_root_candidate="$(git -C "$PLUGIN_ROOT" rev-parse --show-toplevel 2>/dev/null)" \
  || fail 'plugin root is not inside one Git worktree' "$EXIT_BLOCKED_ENVIRONMENT"
REPO_ROOT="$(CDPATH= cd -- "$repo_root_candidate" && pwd -P)" \
  || fail 'could not resolve physical Git worktree root' "$EXIT_BLOCKED_ENVIRONMENT"
readonly REPO_ROOT

if [ "$PLUGIN_ROOT" != "$REPO_ROOT/ifl-ios-standards" ]; then
  fail 'ambiguous plugin root; expected <git-root>/ifl-ios-standards' "$EXIT_BLOCKED_ENVIRONMENT"
fi

LAUNCHER="$PLUGIN_ROOT/bin/ifl-tooling-swift"
readonly LAUNCHER
[ -x "$LAUNCHER" ] \
  || fail 'controlled Swift launcher is missing or not executable' "$EXIT_BLOCKED_ENVIRONMENT"

scratch_parent_input="${TMPDIR:-/tmp}"
[ -d "$scratch_parent_input" ] \
  || fail 'verifier scratch parent is not a directory' "$EXIT_BLOCKED_ENVIRONMENT"
SCRATCH_PARENT="$(CDPATH= cd -- "$scratch_parent_input" && pwd -P)" \
  || fail 'could not physicalize verifier scratch parent' "$EXIT_BLOCKED_ENVIRONMENT"
readonly SCRATCH_PARENT
case "$SCRATCH_PARENT/" in
  "$PLUGIN_ROOT/"|"$PLUGIN_ROOT"/*)
    fail 'verifier scratch parent resolved inside the plugin' "$EXIT_BLOCKED_ENVIRONMENT"
    ;;
esac

SCRATCH="$(mktemp -d "$SCRATCH_PARENT/ifl-candidate-overlay-${CHECKPOINT}.XXXXXX")" \
  || fail 'could not create external verifier scratch' "$EXIT_BLOCKED_ENVIRONMENT"

cleanup_scratch() {
  if [ -n "${SCRATCH:-}" ] && [ -d "$SCRATCH" ]; then
    rm -rf -- "$SCRATCH"
  fi
}

handle_exit() {
  status="$?"
  trap - EXIT HUP INT TERM
  cleanup_scratch
  exit "$status"
}

handle_signal() {
  signal_status="$1"
  trap - EXIT HUP INT TERM
  cleanup_scratch
  exit "$signal_status"
}

trap handle_exit EXIT
trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

scratch_physical="$(CDPATH= cd -- "$SCRATCH" && pwd -P)" \
  || fail 'could not physicalize verifier scratch directory' "$EXIT_BLOCKED_ENVIRONMENT"
SCRATCH="$scratch_physical"
readonly SCRATCH
case "$SCRATCH/" in
  "$PLUGIN_ROOT"/*)
    fail 'verifier scratch resolved inside the plugin' "$EXIT_BLOCKED_ENVIRONMENT"
    ;;
esac

actual_tracked="$SCRATCH/actual-tracked.txt"
actual_untracked="$SCRATCH/actual-untracked.txt"
actual_paths_file="$SCRATCH/actual-paths.txt"
expected_paths_file="$SCRATCH/expected-paths.txt"
git -C "$REPO_ROOT" diff --name-only HEAD -- 'ifl-ios-standards/' > "$actual_tracked" \
  || fail 'could not enumerate tracked checkpoint mutations' "$EXIT_INTERNAL_ERROR"
git -C "$REPO_ROOT" ls-files --others --exclude-standard -- 'ifl-ios-standards/' > "$actual_untracked" \
  || fail 'could not enumerate untracked checkpoint mutations' "$EXIT_INTERNAL_ERROR"
LC_ALL=C sort -u "$actual_tracked" "$actual_untracked" > "$actual_paths_file" \
  || fail 'could not sort checkpoint mutations' "$EXIT_INTERNAL_ERROR"
printf '%s\n' "${expected_paths[@]}" | LC_ALL=C sort -u > "$expected_paths_file" \
  || fail 'could not materialize checkpoint allowlist' "$EXIT_INTERNAL_ERROR"
if ! cmp -s "$actual_paths_file" "$expected_paths_file"; then
  diagnose 'checkpoint changed-file list differs from its exact allowlist'
  diff -u "$expected_paths_file" "$actual_paths_file" >&2 || true
  exit "$EXIT_INTEGRITY"
fi

swift_files=()
expected_swift_paths_file="$SCRATCH/expected-swift-paths.txt"
actual_swift_paths_file="$SCRATCH/actual-swift-paths.txt"
for expected_path in "${expected_paths[@]}"; do
  case "$expected_path" in
    *.swift)
      swift_files+=("$REPO_ROOT/$expected_path")
      printf '%s\n' "$expected_path" >> "$expected_swift_paths_file"
      ;;
  esac
done
: > "$actual_swift_paths_file"
for swift_file in "${swift_files[@]}"; do
  [ -f "$swift_file" ] \
    || fail "declared SwiftFormat file is missing: $swift_file" "$EXIT_INTEGRITY"
  printf '%s\n' "${swift_file#"$REPO_ROOT/"}" >> "$actual_swift_paths_file"
done
LC_ALL=C sort -u -o "$expected_swift_paths_file" "$expected_swift_paths_file" \
  || fail 'could not sort expected SwiftFormat paths' "$EXIT_INTERNAL_ERROR"
LC_ALL=C sort -u -o "$actual_swift_paths_file" "$actual_swift_paths_file" \
  || fail 'could not sort derived SwiftFormat paths' "$EXIT_INTERNAL_ERROR"
cmp -s "$expected_swift_paths_file" "$actual_swift_paths_file" \
  || fail 'derived SwiftFormat paths differ from task-owned Swift paths' "$EXIT_INTEGRITY"

python_bin="$(command -v python3 2>/dev/null)" \
  || fail 'python3 is required for deterministic verifier parsing' "$EXIT_BLOCKED_ENVIRONMENT"
[ -n "$python_bin" ] \
  || fail 'python3 is required for deterministic verifier parsing' "$EXIT_BLOCKED_ENVIRONMENT"
readonly python_bin

INVENTORY_SCANNER="$SCRATCH/plugin-inventory-scanner.py"
readonly INVENTORY_SCANNER
# INVENTORY_SCANNER_PY_START
cat > "$INVENTORY_SCANNER" <<'PY'
import hashlib
import json
import os
import stat
import sys

RESERVED = {".build", ".cache", ".scratch"}


def fail(message, status):
    print(f"candidate-overlay-verifier: {message}", file=sys.stderr)
    raise SystemExit(status)


def signature(value):
    return (
        value.st_dev,
        value.st_ino,
        value.st_mode,
        value.st_nlink,
        value.st_size,
        value.st_mtime_ns,
        value.st_ctime_ns,
    )


def entry_kind(mode):
    if stat.S_ISDIR(mode):
        return "directory"
    if stat.S_ISREG(mode):
        return "regular_file"
    if stat.S_ISLNK(mode):
        return "symlink"
    if stat.S_ISFIFO(mode):
        return "fifo"
    if stat.S_ISSOCK(mode):
        return "socket"
    if stat.S_ISCHR(mode):
        return "character_device"
    if stat.S_ISBLK(mode):
        return "block_device"
    return "unknown"


def encode_path(value):
    return os.fsencode(value).hex()


def scan(root):
    records = []

    def visit(path, relative):
        try:
            before = os.lstat(path)
        except OSError as error:
            fail(f"inventory lstat failed for {relative or '.'}: {error}", 3)
        kind = entry_kind(before.st_mode)
        payload = ""
        if kind == "regular_file":
            digest = hashlib.sha256()
            try:
                with open(path, "rb") as handle:
                    while True:
                        chunk = handle.read(1024 * 1024)
                        if not chunk:
                            break
                        digest.update(chunk)
            except OSError as error:
                fail(f"inventory read failed for {relative}: {error}", 3)
            payload = digest.hexdigest()
        elif kind == "symlink":
            try:
                payload = encode_path(os.readlink(path))
            except OSError as error:
                fail(f"inventory readlink failed for {relative}: {error}", 3)

        records.append([
            encode_path(relative or "."),
            kind,
            stat.S_IMODE(before.st_mode),
            before.st_size,
            payload,
        ])

        if kind == "directory":
            try:
                with os.scandir(path) as iterator:
                    children = sorted(iterator, key=lambda item: os.fsencode(item.name))
            except OSError as error:
                fail(f"inventory traversal failed for {relative or '.'}: {error}", 3)
            for child in children:
                if child.name in RESERVED:
                    child_relative = os.path.join(relative, child.name) if relative else child.name
                    fail(f"package-local artifact node exists: {child_relative}", 5)
                child_relative = os.path.join(relative, child.name) if relative else child.name
                visit(child.path, child_relative)

        try:
            after = os.lstat(path)
        except OSError as error:
            fail(f"inventory post-lstat failed for {relative or '.'}: {error}", 3)
        if signature(before) != signature(after):
            fail(f"plugin inventory changed while scanning: {relative or '.'}", 5)

    visit(root, "")
    records.sort(key=lambda value: bytes.fromhex(value[0]))
    return records


def main():
    if len(sys.argv) != 3:
        fail("inventory scanner requires root and output", 4)
    root, output = sys.argv[1:]
    try:
        root_stat = os.lstat(root)
    except OSError as error:
        fail(f"plugin inventory root is unavailable: {error}", 3)
    if not stat.S_ISDIR(root_stat.st_mode):
        fail("plugin inventory root is not a directory", 3)
    records = scan(root)
    try:
        with open(output, "wb") as handle:
            for record in records:
                handle.write(json.dumps(record, separators=(",", ":"), ensure_ascii=True).encode("ascii"))
                handle.write(b"\n")
    except OSError as error:
        fail(f"could not write plugin inventory: {error}", 4)


if __name__ == "__main__":
    main()
PY
# INVENTORY_SCANNER_PY_END

run_inventory_scan() {
  inventory_output="$1"
  "$python_bin" "$INVENTORY_SCANNER" "$PLUGIN_ROOT" "$inventory_output"
  inventory_status="$?"
  case "$inventory_status" in
    0)
      return 0
      ;;
    3)
      exit "$EXIT_BLOCKED_ENVIRONMENT"
      ;;
    5)
      exit "$EXIT_INTEGRITY"
      ;;
    *)
      fail 'plugin inventory scanner failed internally' "$EXIT_INTERNAL_ERROR"
      ;;
  esac
}

BASE_PLUGIN_INVENTORY="$SCRATCH/plugin-inventory-before.jsonl"
FINAL_PLUGIN_INVENTORY="$SCRATCH/plugin-inventory-after.jsonl"
readonly BASE_PLUGIN_INVENTORY
readonly FINAL_PLUGIN_INVENTORY
run_inventory_scan "$BASE_PLUGIN_INVENTORY"

git_objects_candidate="$(git -C "$REPO_ROOT" rev-parse --git-path objects 2>/dev/null)" \
  || fail 'could not resolve Git object directory' "$EXIT_INTERNAL_ERROR"
case "$git_objects_candidate" in
  /*)
    GIT_OBJECTS="$git_objects_candidate"
    ;;
  *)
    GIT_OBJECTS="$REPO_ROOT/$git_objects_candidate"
    ;;
esac
readonly GIT_OBJECTS
[ -d "$GIT_OBJECTS" ] || fail 'Git object directory is missing' "$EXIT_BLOCKED_ENVIRONMENT"
TEMP_INDEX="$SCRATCH/git-index"
TEMP_OBJECTS="$SCRATCH/git-objects"
readonly TEMP_INDEX
readonly TEMP_OBJECTS
mkdir -p -- "$TEMP_OBJECTS" \
  || fail 'could not create external Git object scratch' "$EXIT_BLOCKED_ENVIRONMENT"
env GIT_INDEX_FILE="$TEMP_INDEX" \
  GIT_OBJECT_DIRECTORY="$TEMP_OBJECTS" \
  GIT_ALTERNATE_OBJECT_DIRECTORIES="$GIT_OBJECTS" \
  git -C "$REPO_ROOT" read-tree HEAD \
  || fail 'could not initialize external whitespace-check index' "$EXIT_INTERNAL_ERROR"
env GIT_INDEX_FILE="$TEMP_INDEX" \
  GIT_OBJECT_DIRECTORY="$TEMP_OBJECTS" \
  GIT_ALTERNATE_OBJECT_DIRECTORIES="$GIT_OBJECTS" \
  git -C "$REPO_ROOT" add -A -- 'ifl-ios-standards/' \
  || fail 'could not populate external whitespace-check index' "$EXIT_INTERNAL_ERROR"
env GIT_INDEX_FILE="$TEMP_INDEX" \
  GIT_OBJECT_DIRECTORY="$TEMP_OBJECTS" \
  GIT_ALTERNATE_OBJECT_DIRECTORIES="$GIT_OBJECTS" \
  git -C "$REPO_ROOT" diff --cached --check HEAD -- 'ifl-ios-standards/' 1>&2 \
  || fail 'whitespace check failed for tracked or untracked checkpoint files' "$EXIT_CONFORMANCE"

PROVENANCE="$PLUGIN_ROOT/verification/fixtures/canon/candidate-overlay/contracts/pre-amendment-v1/provenance.json"
AUTHORITY_FIXTURE="$PLUGIN_ROOT/verification/fixtures/canon/candidate-overlay/contracts/amended-v1/candidate-publication-authority-map.json"
readonly PROVENANCE
readonly AUTHORITY_FIXTURE
readonly EXPECTED_PROVENANCE_SHA='e443b6c6ec758228cc9041c4fa21d744742e2dd3a74090a442c2a746036676a8'
[ -f "$PROVENANCE" ] || fail 'committed governance provenance is missing' "$EXIT_INTEGRITY"
[ -f "$AUTHORITY_FIXTURE" ] || fail 'compiled authority fixture is missing' "$EXIT_INTEGRITY"
actual_provenance_sha="$(shasum -a 256 "$PROVENANCE" | awk '{print $1}')" \
  || fail 'could not hash committed governance provenance' "$EXIT_INTERNAL_ERROR"
[ "$actual_provenance_sha" = "$EXPECTED_PROVENANCE_SHA" ] \
  || fail 'committed governance provenance digest mismatch' "$EXIT_INTEGRITY"

"$python_bin" - "$PROVENANCE" "$AUTHORITY_FIXTURE" <<'PY' 1>&2
import hashlib
import json
import re
import sys


def fail(message, status):
    print(f"candidate-overlay-verifier: {message}", file=sys.stderr)
    raise SystemExit(status)


try:
    provenance_bytes = open(sys.argv[1], "rb").read()
    authority_bytes = open(sys.argv[2], "rb").read()
    provenance = json.loads(provenance_bytes)
    authority = json.loads(authority_bytes)
except (OSError, UnicodeError, json.JSONDecodeError) as error:
    fail(f"governance provenance parse failed: {error}", 4)

canonical = json.dumps(provenance, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8") + b"\n"
if canonical != provenance_bytes:
    fail("governance provenance is not canonical JSON plus LF", 5)

governance = provenance.get("governance")
required = {
    "approved_design_sha256",
    "authority_appendix_sha256",
    "authority_fixture_sha256",
    "authority_map_digest",
    "authority_row_count",
}
if not isinstance(governance, dict) or set(governance) != required:
    fail("governance provenance fields are incomplete or open", 5)
for key in required - {"authority_row_count"}:
    if not isinstance(governance[key], str) or re.fullmatch(r"[0-9a-f]{64}", governance[key]) is None:
        fail(f"governance provenance {key} is not a lowercase SHA-256", 5)
actual_authority_digest = hashlib.sha256(authority_bytes).hexdigest()
if governance["authority_fixture_sha256"] != actual_authority_digest:
    fail("authority fixture digest does not match governance provenance", 5)
if governance["authority_map_digest"] != actual_authority_digest:
    fail("authority map digest does not match its canonical fixture", 5)
rows = authority.get("rows") if isinstance(authority, dict) else None
if governance["authority_row_count"] != 142 or not isinstance(rows, list) or len(rows) != 142:
    fail("compiled authority row count is not exactly 142", 5)
PY
governance_status="$?"
case "$governance_status" in
  0)
    ;;
  4)
    exit "$EXIT_INTERNAL_ERROR"
    ;;
  5)
    exit "$EXIT_INTEGRITY"
    ;;
  *)
    fail 'governance parser returned an undocumented status' "$EXIT_INTERNAL_ERROR"
    ;;
esac

run_launcher_gate() {
  gate_name="$1"
  shift
  "$LAUNCHER" "$@" 1>&2
  launcher_status="$?"
  case "$launcher_status" in
    0) ;;
    1) fail "$gate_name failed through the controlled launcher" "$EXIT_CONFORMANCE" ;;
    2) fail "$gate_name failed through the controlled launcher" "$EXIT_INVALID_INPUT" ;;
    3) fail "$gate_name failed through the controlled launcher" "$EXIT_BLOCKED_ENVIRONMENT" ;;
    4) fail "$gate_name failed through the controlled launcher" "$EXIT_INTERNAL_ERROR" ;;
    5) fail "$gate_name failed through the controlled launcher" "$EXIT_INTEGRITY" ;;
    *)
      fail "$gate_name returned undocumented launcher status $launcher_status" "$EXIT_INTERNAL_ERROR"
      ;;
  esac
}

SWIFTPM_RUN_ROOT="$SCRATCH/swiftpm-run"
readonly SWIFTPM_RUN_ROOT
[ ! -e "$SWIFTPM_RUN_ROOT" ] \
  || fail 'SwiftPM run scratch must start absent' "$EXIT_INTEGRITY"
IFL_SWIFTPM_SCRATCH_ROOT="$SWIFTPM_RUN_ROOT"
readonly IFL_SWIFTPM_SCRATCH_ROOT
export IFL_SWIFTPM_SCRATCH_ROOT

diagnose "running focused checkpoint $CHECKPOINT tests"
run_launcher_gate 'focused checkpoint tests' test --filter "$FOCUSED_FILTER"

readonly CONTRACT_FILTER='IFLContractsTests\.(CandidateOverlayV1CompatibilityTests|CandidateOverlaySchemaParityTests|CandidateOverlayTransformContractTests|CanonSchemaFileTests|CanonSchemaContractTests|CanonSchemaLexicalTests|CanonicalRelativePathParityTests|CanonActivationContractTests)'
if [ "$CHECKPOINT" != '2a' ]; then
  diagnose 'running frozen schema/parity/old-witness contracts'
  run_launcher_gate 'frozen schema/parity/old-witness contracts' test --filter "$CONTRACT_FILTER"
fi

diagnose 'running complete package tests'
run_launcher_gate 'complete package tests' test
diagnose 'running release package build'
run_launcher_gate 'release package build' build -c release

SYMBOL_DIR="$SWIFTPM_RUN_ROOT"
readonly SYMBOL_DIR
diagnose 'dumping public SymbolGraphs'
run_launcher_gate 'public SymbolGraph dump' package dump-symbol-graph \
  --minimum-access-level public

symbol_count="$(find "$SYMBOL_DIR" -type f -name '*.symbols.json' -print | wc -l | tr -d ' ')" \
  || fail 'could not count SymbolGraph files' "$EXIT_INTERNAL_ERROR"
[ "$symbol_count" -gt 0 ] || fail 'SymbolGraph dump produced no graph files' "$EXIT_INTEGRITY"

SYMBOL_PARSER="$SCRATCH/symbol-graph-parser.py"
readonly SYMBOL_PARSER
# SYMBOL_GRAPH_PARSER_PY_START
cat > "$SYMBOL_PARSER" <<'PY'
import glob
import json
import os
import sys

TOKENS = {
    "CanonActivationApprovalInput",
    "ValidatedCandidateOverlay",
    "ResolvedCandidateActivation",
}
FORBIDDEN_PROTOCOLS = {"Codable", "Encodable", "Decodable"}
CONFORMANCE_IDS = {"s:SE", "s:Se"}


def symbol_text(symbol):
    fragments = symbol.get("declarationFragments", [])
    declaration = "".join(fragment.get("spelling", "") for fragment in fragments)
    paths = symbol.get("pathComponents", [])
    title = symbol.get("names", {}).get("title", "")
    return declaration, paths, title, " ".join(paths + [declaration, title])


def analyze(graphs, expected):
    symbols = []
    relationships = []
    graph_names = {}
    for name, graph in graphs:
        for symbol in graph.get("symbols", []):
            precise = symbol.get("identifier", {}).get("precise", "")
            graph_names[precise] = name
            symbols.append(symbol)
        relationships.extend(graph.get("relationships", []))

    by_precise = {
        symbol.get("identifier", {}).get("precise", ""): symbol
        for symbol in symbols
        if symbol.get("identifier", {}).get("precise", "")
    }
    protected_precise = {}
    observed = set()
    for symbol in symbols:
        declaration, paths, title, joined = symbol_text(symbol)
        precise = symbol.get("identifier", {}).get("precise", "")
        for token in TOKENS:
            if token in paths or title == token or token in declaration:
                observed.add(token)
                if title == token or (paths and paths[-1] == token):
                    protected_precise[precise] = token

    member_owner = {}
    owner_relationships = {
        "memberOf",
        "requirementOf",
        "optionalRequirementOf",
        "getterOf",
        "setterOf",
        "willSetOf",
        "didSetOf",
    }
    changed = True
    while changed:
        changed = False
        for relationship in relationships:
            if relationship.get("kind") not in owner_relationships:
                continue
            target = relationship.get("target", "")
            owner = protected_precise.get(target) or member_owner.get(target)
            source = relationship.get("source", "")
            if owner and member_owner.get(source) != owner:
                member_owner[source] = owner
                changed = True

    accessor_targets = {
        relationship.get("source", ""): relationship.get("target", "")
        for relationship in relationships
        if relationship.get("kind") in {"getterOf", "setterOf", "willSetOf", "didSetOf"}
    }

    def output_fragments(symbol):
        kind = symbol.get("kind", {}).get("identifier", "")
        title = symbol.get("names", {}).get("title", "")
        callable_or_subscript = (
            kind.startswith("swift.func")
            or kind in {"swift.method", "swift.type.method", "swift.operator"}
            or "subscript" in kind
            or title.startswith("subscript(")
        )
        returns = symbol.get("functionSignature", {}).get("returns")
        if isinstance(returns, list):
            return returns
        fragments = symbol.get("declarationFragments", [])
        if not callable_or_subscript:
            return fragments
        output = []
        arrow_seen = False
        for fragment in fragments:
            spelling = fragment.get("spelling", "")
            if arrow_seen:
                output.append(fragment)
            elif "->" in spelling:
                arrow_seen = True
                suffix = spelling.split("->", 1)[1]
                if suffix:
                    output_fragment = dict(fragment)
                    output_fragment["spelling"] = suffix
                    output.append(output_fragment)
        return output

    output_references_by_precise = {}
    output_tokens_by_precise = {}
    for symbol in symbols:
        precise = symbol.get("identifier", {}).get("precise", "")
        fragments = output_fragments(symbol)
        output_text = "".join(fragment.get("spelling", "") for fragment in fragments)
        precise_references = {
            fragment.get("preciseIdentifier", "")
            for fragment in fragments
            if fragment.get("preciseIdentifier", "")
        }
        if precise_references:
            output_references_by_precise[precise] = precise_references
        tokens = {
            protected_precise[reference]
            for reference in precise_references
            if reference in protected_precise
        }
        tokens.update(token for token in TOKENS if token in output_text)
        owner = member_owner.get(precise)
        if owner and any(fragment.get("spelling", "").strip() == "Self" for fragment in fragments):
            tokens.add(owner)
        if tokens:
            output_tokens_by_precise[precise] = tokens
    changed = True
    while changed:
        changed = False
        for source, precise_references in output_references_by_precise.items():
            inherited = set()
            for target in precise_references:
                token = protected_precise.get(target)
                if token:
                    inherited.add(token)
                inherited.update(output_tokens_by_precise.get(target, set()))
            if inherited - output_tokens_by_precise.get(source, set()):
                output_tokens_by_precise.setdefault(source, set()).update(inherited)
                changed = True
        for relationship in relationships:
            source = relationship.get("source", "")
            target = relationship.get("target", "")
            inherited = set()
            if relationship.get("kind") in {"returns", "typeOf"}:
                token = protected_precise.get(target)
                if token:
                    inherited.add(token)
                inherited.update(output_tokens_by_precise.get(target, set()))
            if relationship.get("kind") in {"getterOf", "setterOf", "willSetOf", "didSetOf"}:
                inherited.update(output_tokens_by_precise.get(target, set()))
            if inherited - output_tokens_by_precise.get(source, set()):
                output_tokens_by_precise.setdefault(source, set()).update(inherited)
                changed = True

    violations = []
    for symbol in symbols:
        if symbol.get("accessLevel") != "public":
            continue
        declaration, paths, title, joined = symbol_text(symbol)
        precise = symbol.get("identifier", {}).get("precise", "")
        kind = symbol.get("kind", {}).get("identifier", "")
        output_tokens = output_tokens_by_precise.get(precise, set())
        owner = member_owner.get(precise)
        graph_name = graph_names.get(precise, "symbol-graph")

        if "CandidateOverlayArtifactSource" in joined:
            violations.append(f"{graph_name}: public CandidateOverlayArtifactSource")
        if precise in protected_precise:
            continue

        is_initializer = kind == "swift.init" or title.startswith("init(")
        is_callable = kind in {
            "swift.func",
            "swift.func.op",
            "swift.method",
            "swift.type.method",
            "swift.operator",
        } or kind.startswith("swift.func.")
        is_property = any(part in kind for part in ("property", "var"))
        is_subscript = "subscript" in kind or title.startswith("subscript(")
        is_alias = "typealias" in kind or declaration.lstrip().startswith("typealias ")
        is_accessor = "getter" in kind or "setter" in kind or "accessor" in kind
        is_static = "static " in declaration or "class var " in declaration or kind.startswith("swift.type.")
        accessor_target = by_precise.get(accessor_targets.get(precise, ""), {})
        accessor_declaration, _, _, _ = symbol_text(accessor_target)
        accessor_kind = accessor_target.get("kind", {}).get("identifier", "")
        is_static = is_static or (
            "static " in accessor_declaration
            or "class var " in accessor_declaration
            or accessor_kind.startswith("swift.type.")
        )
        is_mutable_instance = owner and not is_static and (
            (is_property and " var " in f" {declaration} ")
            or (is_accessor and "setter" in kind)
        )

        if owner and is_initializer:
            violations.append(f"{graph_name}: public initializer for {owner}: {title}")
        if owner and is_callable and output_tokens:
            violations.append(f"{graph_name}: public callable source for {owner}: {title}")
        if owner and ((is_static or is_subscript) and output_tokens or is_mutable_instance):
            violations.append(f"{graph_name}: public mutable/static/subscript source for {owner}: {title}")
        if output_tokens and (is_callable or is_property or is_subscript or is_alias or is_accessor):
            tokens = ",".join(sorted(output_tokens))
            violations.append(f"{graph_name}: public alias-mediated source for {tokens}: {title}")
        if output_tokens and any(protocol in declaration for protocol in FORBIDDEN_PROTOCOLS):
            violations.append(f"{graph_name}: forbidden Codable surface in {declaration}")

    for relationship in relationships:
        if relationship.get("kind") != "conformsTo":
            continue
        source = by_precise.get(relationship.get("source", ""), {})
        source_precise = relationship.get("source", "")
        source_token = protected_precise.get(source_precise)
        if not source_token:
            _, _, _, source_joined = symbol_text(source)
            source_token = next((token for token in TOKENS if token in source_joined), None)
        if not source_token:
            continue
        target_text = " ".join([
            relationship.get("target", ""),
            relationship.get("targetFallback", ""),
        ])
        if relationship.get("target") in CONFORMANCE_IDS or any(
            protocol in target_text for protocol in FORBIDDEN_PROTOCOLS
        ):
            violations.append(f"forbidden conformance {source_token} -> {target_text}")

    if expected not in observed:
        violations.append(f"expected protected symbol was not observed: {expected}")
    return sorted(set(violations))


def protected_symbol():
    return {
        "identifier": {"precise": "s:Protected"},
        "accessLevel": "public",
        "kind": {"identifier": "swift.struct"},
        "names": {"title": "CanonActivationApprovalInput"},
        "pathComponents": ["CanonActivationApprovalInput"],
        "declarationFragments": [
            {"spelling": "public struct CanonActivationApprovalInput"},
        ],
    }


def self_test():
    base = protected_symbol()
    positive = [("positive", {"symbols": [base], "relationships": []})]
    if analyze(positive, "CanonActivationApprovalInput"):
        raise AssertionError("positive SymbolGraph probe was rejected")

    synthesized_not_equal = {
        "identifier": {
            "precise": "s:SQsE2neoiySbx_xtFZ::SYNTHESIZED::s:Protected",
        },
        "accessLevel": "public",
        "kind": {"identifier": "swift.func.op"},
        "names": {"title": "!=(_:_:)"},
        "pathComponents": ["CanonActivationApprovalInput", "!=(_:_:)"],
        "declarationFragments": [
            {"kind": "keyword", "spelling": "static"},
            {"kind": "text", "spelling": " "},
            {"kind": "keyword", "spelling": "func"},
            {"kind": "text", "spelling": " "},
            {"kind": "identifier", "spelling": "!="},
            {"kind": "text", "spelling": " ("},
            {"kind": "internalParam", "spelling": "lhs"},
            {"kind": "text", "spelling": ": "},
            {"kind": "typeIdentifier", "spelling": "Self"},
            {"kind": "text", "spelling": ", "},
            {"kind": "internalParam", "spelling": "rhs"},
            {"kind": "text", "spelling": ": "},
            {"kind": "typeIdentifier", "spelling": "Self"},
            {"kind": "text", "spelling": ") -> "},
            {"kind": "typeIdentifier", "spelling": "Bool", "preciseIdentifier": "s:Sb"},
        ],
        "functionSignature": {
            "parameters": [
                {
                    "name": "lhs",
                    "declarationFragments": [
                        {"kind": "identifier", "spelling": "lhs"},
                        {"kind": "text", "spelling": ": "},
                        {"kind": "typeIdentifier", "spelling": "Self"},
                    ],
                },
                {
                    "name": "rhs",
                    "declarationFragments": [
                        {"kind": "identifier", "spelling": "rhs"},
                        {"kind": "text", "spelling": ": "},
                        {"kind": "typeIdentifier", "spelling": "Self"},
                    ],
                },
            ],
            "returns": [
                {"kind": "typeIdentifier", "spelling": "Bool", "preciseIdentifier": "s:Sb"},
            ],
        },
    }
    synthesized_graph = [(
        "synthesized-consumer-positive",
        {
            "symbols": [base, synthesized_not_equal],
            "relationships": [
                {
                    "kind": "memberOf",
                    "source": synthesized_not_equal["identifier"]["precise"],
                    "target": "s:Protected",
                    "sourceOrigin": {
                        "identifier": "s:SQsE2neoiySbx_xtFZ",
                        "displayName": "Equatable.!=(_:_:)",
                    },
                },
            ],
        },
    )]
    bool_consumer = {
        "identifier": {"precise": "s:BoolConsumer"},
        "accessLevel": "public",
        "kind": {"identifier": "swift.func"},
        "names": {"title": "isApproved(_:)"},
        "pathComponents": ["isApproved(_:)"],
        "declarationFragments": [
            {"spelling": "public func isApproved(input: "},
            {"spelling": "CanonActivationApprovalInput", "preciseIdentifier": "s:Protected"},
            {"spelling": ") -> "},
            {"spelling": "Bool", "preciseIdentifier": "s:Sb"},
        ],
        "functionSignature": {
            "parameters": [
                {
                    "name": "input",
                    "declarationFragments": [
                        {"spelling": "input: "},
                        {
                            "spelling": "CanonActivationApprovalInput",
                            "preciseIdentifier": "s:Protected",
                        },
                    ],
                },
            ],
            "returns": [
                {"spelling": "Bool", "preciseIdentifier": "s:Sb"},
            ],
        },
    }
    consumer_graph = [(
        "consumer-positive",
        {"symbols": [base, bool_consumer], "relationships": []},
    )]
    positive_consumer_failures = []
    if analyze(synthesized_graph, "CanonActivationApprovalInput"):
        positive_consumer_failures.append("synthesized Equatable !=")
    if analyze(consumer_graph, "CanonActivationApprovalInput"):
        positive_consumer_failures.append("Bool-returning protected-token consumer")

    source_cases = [
        ("swift.type.property", "shared", "public static var shared: "),
        ("swift.subscript", "subscript(_:)", "public subscript(index: Int) -> "),
        ("swift.typealias", "ApprovalAlias", "public typealias ApprovalAlias = "),
        ("swift.func", "make()", "public func make() -> "),
    ]
    for index, (kind, title, spelling) in enumerate(source_cases):
        source = {
            "identifier": {"precise": f"s:Source{index}"},
            "accessLevel": "public",
            "kind": {"identifier": kind},
            "names": {"title": title},
            "pathComponents": [title],
            "declarationFragments": [
                {"spelling": spelling},
                {"spelling": "CanonActivationApprovalInput", "preciseIdentifier": "s:Protected"},
            ],
        }
        violations = analyze(
            [("negative", {"symbols": [base, source], "relationships": []})],
            "CanonActivationApprovalInput",
        )
        if not violations:
            raise AssertionError(f"negative SymbolGraph probe was accepted: {kind}")

    initializer = {
        "identifier": {"precise": "s:Initializer"},
        "accessLevel": "public",
        "kind": {"identifier": "swift.init"},
        "names": {"title": "init(raw:)"},
        "pathComponents": ["CanonActivationApprovalInput", "init(raw:)"],
        "declarationFragments": [{"spelling": "public init(raw: String)"}],
    }
    initializer_violations = analyze(
        [(
            "initializer-negative",
            {
                "symbols": [base, initializer],
                "relationships": [
                    {"kind": "memberOf", "source": "s:Initializer", "target": "s:Protected"},
                ],
            },
        )],
        "CanonActivationApprovalInput",
    )
    if not initializer_violations:
        raise AssertionError("negative protected initializer probe was accepted")

    approval_alias = {
        "identifier": {"precise": "s:ApprovalAlias"},
        "accessLevel": "public",
        "kind": {"identifier": "swift.typealias"},
        "names": {"title": "ApprovalAlias"},
        "pathComponents": ["ApprovalAlias"],
        "declarationFragments": [
            {"spelling": "public typealias ApprovalAlias = "},
            {"spelling": "CanonActivationApprovalInput", "preciseIdentifier": "s:Protected"},
        ],
    }
    alias_factory = {
        "identifier": {"precise": "s:AliasFactory"},
        "accessLevel": "public",
        "kind": {"identifier": "swift.func"},
        "names": {"title": "makeAlias()"},
        "pathComponents": ["makeAlias()"],
        "declarationFragments": [
            {"spelling": "public func makeAlias() -> "},
            {"spelling": "ApprovalAlias", "preciseIdentifier": "s:ApprovalAlias"},
        ],
        "functionSignature": {
            "parameters": [],
            "returns": [
                {"spelling": "ApprovalAlias", "preciseIdentifier": "s:ApprovalAlias"},
            ],
        },
    }
    alias_factory_violations = analyze(
        [(
            "alias-factory-negative",
            {"symbols": [base, approval_alias, alias_factory], "relationships": []},
        )],
        "CanonActivationApprovalInput",
    )
    if not any("makeAlias()" in violation for violation in alias_factory_violations):
        positive_consumer_failures.append("alias-returning factory was accepted")

    property_symbol = {
        "identifier": {"precise": "s:Property"},
        "accessLevel": "public",
        "kind": {"identifier": "swift.property"},
        "names": {"title": "captured"},
        "pathComponents": ["Factory", "captured"],
        "declarationFragments": [
            {"spelling": "public var captured: "},
            {"spelling": "CanonActivationApprovalInput", "preciseIdentifier": "s:Protected"},
        ],
    }
    getter_symbol = {
        "identifier": {"precise": "s:Getter"},
        "accessLevel": "public",
        "kind": {"identifier": "swift.getter"},
        "names": {"title": "get"},
        "pathComponents": ["Factory", "captured", "get"],
        "declarationFragments": [{"spelling": "get"}],
    }
    accessor_violations = analyze(
        [(
            "accessor-negative",
            {
                "symbols": [base, property_symbol, getter_symbol],
                "relationships": [
                    {"kind": "getterOf", "source": "s:Getter", "target": "s:Property"},
                ],
            },
        )],
        "CanonActivationApprovalInput",
    )
    if not accessor_violations:
        raise AssertionError("negative accessor relationship probe was accepted")

    if not analyze([("missing", {"symbols": [], "relationships": []})], "CanonActivationApprovalInput"):
        raise AssertionError("missing-token SymbolGraph probe was accepted")
    if positive_consumer_failures:
        raise AssertionError("; ".join(positive_consumer_failures))


def scan(root, expected):
    paths = sorted(glob.glob(os.path.join(root, "**", "*.symbols.json"), recursive=True))
    graphs = []
    try:
        for path in paths:
            with open(path, "rb") as handle:
                graphs.append((os.path.basename(path), json.load(handle)))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        print(f"candidate-overlay-verifier: SymbolGraph parser I/O failure: {error}", file=sys.stderr)
        raise SystemExit(4)
    violations = analyze(graphs, expected)
    if violations:
        for violation in violations:
            print(f"candidate-overlay-verifier: {violation}", file=sys.stderr)
        raise SystemExit(5)


def main():
    if sys.argv[1:] == ["--self-test"]:
        try:
            self_test()
        except Exception as error:
            print(f"candidate-overlay-verifier: SymbolGraph self-test failed: {error}", file=sys.stderr)
            raise SystemExit(4)
        return
    if len(sys.argv) != 3 or sys.argv[1] != "--scan":
        print("candidate-overlay-verifier: invalid SymbolGraph parser invocation", file=sys.stderr)
        raise SystemExit(4)
    scan(sys.argv[2], os.environ.get("IFL_EXPECTED_PROTECTED_SYMBOL", ""))


if __name__ == "__main__":
    main()
PY
# SYMBOL_GRAPH_PARSER_PY_END

"$python_bin" "$SYMBOL_PARSER" --self-test 1>&2
parser_probe_status="$?"
[ "$parser_probe_status" -eq 0 ] \
  || fail 'SymbolGraph causal parser probes failed' "$EXIT_INTERNAL_ERROR"

IFL_EXPECTED_PROTECTED_SYMBOL="$PROTECTED_SYMBOL" \
  "$python_bin" "$SYMBOL_PARSER" --scan "$SYMBOL_DIR" 1>&2
symbol_status="$?"
case "$symbol_status" in
  0)
    ;;
  4)
    exit "$EXIT_INTERNAL_ERROR"
    ;;
  5)
    exit "$EXIT_INTEGRITY"
    ;;
  *)
    fail 'SymbolGraph parser returned an undocumented status' "$EXIT_INTERNAL_ERROR"
    ;;
esac

swiftformat_bin="$(command -v swiftformat 2>/dev/null)" \
  || fail 'SwiftFormat is required for the checkpoint gate' "$EXIT_BLOCKED_ENVIRONMENT"
[ -n "$swiftformat_bin" ] \
  || fail 'SwiftFormat is required for the checkpoint gate' "$EXIT_BLOCKED_ENVIRONMENT"
readonly swiftformat_bin
diagnose 'linting Swift files derived from the exact checkpoint allowlist'
"$swiftformat_bin" --lint --swift-version 6.0 --cache "$SCRATCH/swiftformat.cache" \
  "${swift_files[@]}" 1>&2
swiftformat_status="$?"
[ "$swiftformat_status" -eq 0 ] || fail 'SwiftFormat lint failed' "$EXIT_CONFORMANCE"

run_inventory_scan "$FINAL_PLUGIN_INVENTORY"
cmp -s "$BASE_PLUGIN_INVENTORY" "$FINAL_PLUGIN_INVENTORY" \
  || fail 'plugin lstat/mode/content/symlink inventory changed during verification' "$EXIT_INTEGRITY"

printf 'checkpoint=%s\n' "$CHECKPOINT"
printf 'status=passed\n'
printf 'focused=passed\n'
printf 'full_tests=passed\n'
printf 'release_build=passed\n'
printf 'symbol_graphs=%s\n' "$symbol_count"
printf 'authority_rows=142\n'
exit "$EXIT_PASSED"
