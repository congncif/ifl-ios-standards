#!/bin/bash
set -u

expected_parent="0a9946bcd5004773408f6e5e7569fb545f5d30c6"
expected_inventory_sha="728f397d10eac4e32e2e6c6af3d43576f621253f1e9ea226945d4d46fd1dbbef"
workflow_symbol='IFL''Workflow'
workflow_command='ifl-''workflow'
reference_pattern="${workflow_symbol}|${workflow_command}|Kernel-bound|Kernel-owned|[\"']IFL[\"'][[:space:]]*[+][[:space:]]*[\"']Workflow[\"']"

root=""
format="human"
phase=""
checkpoint=""
selector=""
inventory=""
manifest=""
seen_root=0
seen_format=0
seen_phase=0
seen_checkpoint=0
seen_selector=0
seen_inventory=0
seen_manifest=0
scratch=""

invalid() {
    message=$1
    if [ "$format" = "json" ]; then
        if command -v jq >/dev/null 2>&1; then
            jq -cn --arg message "$message" '{message:$message,status:"invalid_input"}' 2>/dev/null ||
                printf '%s\n' '{"message":"unable to encode diagnostic","status":"invalid_input"}'
        else
            printf '%s\n' '{"message":"JSON encoder unavailable","status":"invalid_input"}'
        fi
    else
        printf 'invalid input: %s\n' "$message" >&2
    fi
    exit 2
}

has_control() {
    LC_ALL=C printf '%s' "$1" | LC_ALL=C grep -q '[[:cntrl:]]'
    status=$?
    [ "$status" -eq 0 ] && return 0
    [ "$status" -eq 1 ] && return 1
    return 0
}

require_value() {
    option=$1
    value=${2-}
    [ -n "$value" ] || invalid "missing value for $option"
    case "$value" in
        -*) invalid "invalid leading-dash value for $option" ;;
    esac
    has_control "$value" && invalid "control character in value for $option"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)
            [ "$seen_root" -eq 0 ] || invalid "duplicate option --root"
            require_value "$1" "${2-}"; root=$2; seen_root=1; shift 2 ;;
        --format)
            [ "$seen_format" -eq 0 ] || invalid "duplicate option --format"
            require_value "$1" "${2-}"; format=$2; seen_format=1; shift 2 ;;
        --phase)
            [ "$seen_phase" -eq 0 ] || invalid "duplicate option --phase"
            require_value "$1" "${2-}"; phase=$2; seen_phase=1; shift 2 ;;
        --checkpoint)
            [ "$seen_checkpoint" -eq 0 ] || invalid "duplicate option --checkpoint"
            require_value "$1" "${2-}"; checkpoint=$2; seen_checkpoint=1; shift 2 ;;
        --selector)
            [ "$seen_selector" -eq 0 ] || invalid "duplicate option --selector"
            require_value "$1" "${2-}"; selector=$2; seen_selector=1; shift 2 ;;
        --inventory)
            [ "$seen_inventory" -eq 0 ] || invalid "duplicate option --inventory"
            require_value "$1" "${2-}"; inventory=$2; seen_inventory=1; shift 2 ;;
        --manifest)
            [ "$seen_manifest" -eq 0 ] || invalid "duplicate option --manifest"
            require_value "$1" "${2-}"; manifest=$2; seen_manifest=1; shift 2 ;;
        --*) invalid "unknown option $1" ;;
        *) invalid "unexpected argument $1" ;;
    esac
done

[ "$seen_root" -eq 1 ] || invalid "missing required option --root"
case "$format" in human|json) ;; *) invalid "unsupported format $format" ;; esac
if [ "$seen_phase" -eq 0 ]; then
    [ "$seen_checkpoint" -eq 0 ] || invalid "--checkpoint requires --phase"
    [ "$seen_selector" -eq 0 ] || invalid "--selector requires --phase"
    [ "$seen_inventory" -eq 0 ] || invalid "--inventory requires --phase"
    [ "$seen_manifest" -eq 0 ] || invalid "--manifest requires --phase"
else
    [ "$phase" = "review-readiness" ] || invalid "unsupported phase $phase"
    [ "$seen_checkpoint" -eq 1 ] || invalid "missing required option --checkpoint"
    [ "$checkpoint" = "07.0" ] || invalid "unsupported checkpoint $checkpoint"
    [ "$seen_selector" -eq 1 ] || invalid "missing required option --selector"
    [ "$selector" = "kernel-quarantine-closure" ] || invalid "unsupported selector $selector"
    [ "$seen_inventory" -eq 1 ] || invalid "missing required option --inventory"
    [ "$seen_manifest" -eq 1 ] || invalid "missing required option --manifest"
    [ "$format" = "json" ] || invalid "review-readiness requires --format json"
    [ ! -L "$inventory" ] && [ -f "$inventory" ] && [ -r "$inventory" ] ||
        invalid "inventory must be a readable regular file"
    [ ! -L "$manifest" ] && [ -f "$manifest" ] && [ -r "$manifest" ] ||
        invalid "manifest must be a readable regular file"
fi

command -v jq >/dev/null 2>&1 || invalid "jq is required"
[ ! -L "$root" ] && [ -d "$root" ] || invalid "root must be a non-symlink directory"
root=$(CDPATH= cd "$root" 2>/dev/null && pwd -P) || invalid "cannot resolve root"
repository=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null) ||
    invalid "root is not in a Git worktree"
repository=$(CDPATH= cd "$repository" 2>/dev/null && pwd -P) ||
    invalid "cannot resolve worktree root"
[ "$root" = "$repository/ifl-ios-standards" ] ||
    invalid "root must name the ifl-ios-standards directory"

git_dir_raw=$(git -C "$repository" rev-parse --git-dir 2>/dev/null) ||
    invalid "cannot resolve Git directory"
case "$git_dir_raw" in /*) git_dir_path=$git_dir_raw ;; *) git_dir_path="$repository/$git_dir_raw" ;; esac
git_dir=$(CDPATH= cd "$git_dir_path" 2>/dev/null && pwd -P) ||
    invalid "cannot resolve Git directory"
common_raw=$(git -C "$repository" rev-parse --git-common-dir 2>/dev/null) ||
    invalid "cannot resolve common Git directory"
case "$common_raw" in /*) common_path=$common_raw ;; *) common_path="$repository/$common_raw" ;; esac
common_git_dir=$(CDPATH= cd "$common_path" 2>/dev/null && pwd -P) ||
    invalid "cannot resolve common Git directory"
[ "${common_git_dir##*/}" = ".git" ] || invalid "unsupported common Git directory layout"
repository_identity_root=${common_git_dir%/.git}
current_branch=$(git -C "$repository" symbolic-ref -q HEAD 2>/dev/null) ||
    invalid "detached HEAD is not supported"
current_head=$(git -C "$repository" rev-parse --verify HEAD 2>/dev/null) ||
    invalid "cannot resolve current HEAD"

scratch_parent=${TMPDIR:-/tmp}
[ -d "$scratch_parent" ] || invalid "temporary directory parent is invalid"
scratch_parent=$(CDPATH= cd "$scratch_parent" 2>/dev/null && pwd -P) ||
    invalid "cannot resolve temporary directory parent"
scratch=$(umask 077 && mktemp -d "$scratch_parent/ifl-release-surface.XXXXXX") ||
    invalid "cannot create scratch directory"
[ ! -L "$scratch" ] && [ -d "$scratch" ] || invalid "scratch directory type is invalid"
scratch=$(CDPATH= cd "$scratch" 2>/dev/null && pwd -P) ||
    invalid "cannot resolve scratch directory"
case "$scratch" in "$scratch_parent"/ifl-release-surface.*) ;; *) invalid "scratch directory escaped" ;; esac
scratch_mode=$(stat -f '%Lp' "$scratch" 2>/dev/null) ||
    scratch_mode=$(stat -c '%a' "$scratch" 2>/dev/null) ||
    invalid "cannot inspect scratch directory mode"
[ "$scratch_mode" = "700" ] || invalid "scratch directory mode is not 0700"

cleanup() {
    if [ -n "$scratch" ] && [ ! -L "$scratch" ] && [ -d "$scratch" ]; then
        case "$scratch" in "$scratch_parent"/ifl-release-surface.*) rm -rf "$scratch" ;; esac
    fi
}
trap cleanup EXIT HUP INT TERM

violations="$scratch/violations"
: >"$violations" || invalid "cannot initialize diagnostics"
add_violation() { printf '%s\n' "$1" >>"$violations" || invalid "cannot record diagnostic"; }
scan_reference() { LC_ALL=C grep -Eq "$reference_pattern" -- "$1"; return $?; }

path_has_symlink_component() {
    remainder=$1
    cursor=$repository
    while [ -n "$remainder" ]; do
        case "$remainder" in
            */*) component=${remainder%%/*}; remainder=${remainder#*/} ;;
            *) component=$remainder; remainder="" ;;
        esac
        cursor="$cursor/$component"
        [ ! -L "$cursor" ] || return 0
    done
    return 1
}

if stat -f '%d:%i:%z:%m:%c:%p' "$repository" >/dev/null 2>&1; then
    stat_style=bsd
else
    stat_style=gnu
fi
stat_signature() {
    [ "$stat_style" = bsd ] &&
        stat -f '%d:%i:%z:%m:%c:%p' "$1" ||
        stat -c '%d:%i:%s:%Y:%Z:%f' "$1"
}

package="$root/tools/ifl-tooling/Package.swift"
if [ -L "$package" ]; then
    add_violation "observation:symlink:ifl-ios-standards/tools/ifl-tooling/Package.swift"
elif [ ! -f "$package" ]; then
    add_violation "missing:ifl-ios-standards/tools/ifl-tooling/Package.swift"
elif [ ! -r "$package" ]; then
    add_violation "observation:unreadable:ifl-ios-standards/tools/ifl-tooling/Package.swift"
else
    scan_reference "$package"; status=$?
    [ "$status" -eq 1 ] || {
        [ "$status" -eq 0 ] &&
            add_violation "package:ifl-ios-standards/tools/ifl-tooling/Package.swift" ||
            add_violation "observation:read-error:ifl-ios-standards/tools/ifl-tooling/Package.swift"
    }
fi

for directory in \
    "$root/tools/ifl-tooling/Sources/$workflow_symbol" \
    "$root/tools/ifl-tooling/Tests/${workflow_symbol}Tests" \
    "$root/verification/fixtures/workflow"
do
    if [ -L "$directory" ]; then
        add_violation "observation:symlink:${directory#$repository/}"
    elif [ -e "$directory" ] && [ ! -d "$directory" ]; then
        add_violation "observation:special-file:${directory#$repository/}"
    elif [ -d "$directory" ]; then
        if find "$directory" -mindepth 1 -print0 >"$scratch/quarantined"; then
            while IFS= read -r -d '' candidate; do
                add_violation "present:${candidate#$repository/}"
            done <"$scratch/quarantined"
        else
            add_violation "observation:find-error:${directory#$repository/}"
        fi
    fi
done

for relative in \
    standards/canon/schemas/v1/approval.schema.json \
    standards/canon/schemas/v1/issue-register.schema.json \
    standards/canon/schemas/v1/remediation-batch.schema.json \
    standards/canon/schemas/v1/review-baseline.schema.json \
    standards/canon/schemas/v1/review-confirmation-receipt.schema.json \
    standards/canon/schemas/v1/review-convergence-receipt.schema.json \
    standards/canon/schemas/v1/reviewer-finding-inventory.schema.json \
    standards/canon/schemas/v1/workflow-event.schema.json \
    standards/canon/schemas/v1/workflow-state.schema.json
do
    [ ! -e "$root/$relative" ] && [ ! -L "$root/$relative" ] ||
        add_violation "present:ifl-ios-standards/$relative"
done

paths="$scratch/repository-paths"
find "$repository" \( -path "$repository/.git" -o -path "$repository/.superpowers" \) -prune -o \
    -print0 >"$paths" || add_violation "observation:find-error:repository"
while IFS= read -r -d '' file; do
    [ "$file" != "$repository" ] || continue
    relative=${file#$repository/}
    if has_control "$relative"; then add_violation "observation:unsafe-path"; continue; fi
    if [ -L "$file" ]; then add_violation "observation:symlink:$relative"; continue; fi
    [ ! -d "$file" ] || continue
    if [ ! -f "$file" ]; then add_violation "observation:special-file:$relative"; continue; fi
    if [ ! -r "$file" ]; then add_violation "observation:unreadable:$relative"; continue; fi
    before=$(stat_signature "$file" 2>/dev/null); before_status=$?
    if [ "$before_status" -ne 0 ]; then add_violation "observation:stat-error:$relative"; continue; fi
    if [ -s "$file" ]; then
        LC_ALL=C grep -Iq '^' -- "$file"; text_status=$?
        if [ "$text_status" -eq 1 ]; then add_violation "observation:binary:$relative"; continue; fi
        if [ "$text_status" -gt 1 ]; then add_violation "observation:read-error:$relative"; continue; fi
    fi
    case "$relative" in
        ifl-ios-standards/scripts/verify-release-surface.sh|\
        ifl-ios-standards/verification/fixtures/release-surface/negative/kernel-reference.json) ;;
        *)
            scan_reference "$file"; scan_status=$?
            [ "$scan_status" -eq 1 ] || {
                [ "$scan_status" -eq 0 ] &&
                    add_violation "reference:$relative" ||
                    add_violation "observation:read-error:$relative"
            }
            ;;
    esac
    after=$(stat_signature "$file" 2>/dev/null); after_status=$?
    if [ "$after_status" -ne 0 ]; then
        add_violation "observation:stat-error:$relative"
    elif [ "$before" != "$after" ]; then
        add_violation "observation:raced:$relative"
    fi
done <"$paths"

fixture="$root/verification/fixtures/release-surface/negative/kernel-reference.json"
negative_fixture_rejected=false
fixture_valid=1
if [ -L "$fixture" ] || [ ! -f "$fixture" ] || [ ! -r "$fixture" ]; then
    add_violation "fixture:invalid-type"; fixture_valid=0
elif ! jq -cS . "$fixture" >"$scratch/fixture-canonical" 2>/dev/null; then
    add_violation "fixture:parse"; fixture_valid=0
elif ! cmp -s "$fixture" "$scratch/fixture-canonical"; then
    add_violation "fixture:canonical-json"; fixture_valid=0
fi
if [ "$fixture_valid" -eq 1 ] && ! jq -e '
    type == "object" and
    keys == ["content","expected_finding","expected_result","path","schema"] and
    .schema == "ifl.release-surface.virtual-file/v1" and
    .path == "skills/example/SKILL.md" and
    .expected_finding == "supported-release-reference" and
    .expected_result == "rejected" and
    ((.content | type) == "string")
' "$fixture" >/dev/null 2>&1; then
    add_violation "fixture:contract"; fixture_valid=0
fi
if [ "$fixture_valid" -eq 1 ]; then
    if jq -j '.content' "$fixture" >"$scratch/fixture-content" 2>/dev/null; then
        scan_reference "$scratch/fixture-content"; fixture_status=$?
        case "$fixture_status" in
            0) negative_fixture_rejected=true ;;
            1) add_violation "fixture:not-rejected" ;;
            *) add_violation "fixture:read-error" ;;
        esac
    else
        add_violation "fixture:content-extraction"
    fi
fi

manifest_sha=""
if [ "$phase" = "review-readiness" ]; then
    actual_inventory_sha=$(shasum -a 256 "$inventory" 2>/dev/null | awk '{print $1}')
    [ -n "$actual_inventory_sha" ] && [ "$actual_inventory_sha" = "$expected_inventory_sha" ] ||
        add_violation "manifest:inventory-sha"
    manifest_sha=$(shasum -a 256 "$manifest" 2>/dev/null | awk '{print $1}')
    [ -n "$manifest_sha" ] || add_violation "manifest:read"

    manifest_valid=1
    if ! jq -cS . "$manifest" >"$scratch/manifest-canonical" 2>/dev/null; then
        add_violation "manifest:parse"; manifest_valid=0
    elif ! cmp -s "$manifest" "$scratch/manifest-canonical"; then
        add_violation "manifest:canonical-json"; manifest_valid=0
    fi
    if [ "$manifest_valid" -eq 1 ]; then
        jq -e --arg branch "$current_branch" '.worktree.branch == $branch' "$manifest" >/dev/null 2>&1 ||
            add_violation "manifest:worktree-branch"
        if ! jq -e \
            --arg parent "$expected_parent" \
            --arg inventory_sha "$expected_inventory_sha" \
            --arg repository_root "$repository_identity_root" \
            --arg common_git_dir "$common_git_dir" \
            --arg worktree_root "$repository" \
            --arg git_dir "$git_dir" \
            --arg branch "$current_branch" \
            --arg current_head "$current_head" '
            type == "object" and
            keys == ["checkpoint","entries","entry_count","inventory_sha256","parent","repository","schema","worktree"] and
            .schema == "ifl.release-surface.paths/v1" and .checkpoint == "07.0" and
            .parent == $parent and .inventory_sha256 == $inventory_sha and .entry_count == 123 and
            (.repository | type) == "object" and
            (.repository | keys) == ["common_git_dir","root"] and
            .repository.root == $repository_root and .repository.common_git_dir == $common_git_dir and
            (.worktree | type) == "object" and
            (.worktree | keys) == ["branch","current_head","git_dir","root"] and
            .worktree.root == $worktree_root and .worktree.git_dir == $git_dir and
            .worktree.branch == $branch and .worktree.current_head == $current_head and
            (.entries | type) == "array" and (.entries | length) == 123 and
            [.entries[].path] == ([.entries[].path] | sort) and
            ([.entries[].path] | unique | length) == 123 and
            all(.entries[];
                type == "object" and
                keys == ["disposition","final_blob","final_mode","final_state","parent_blob","parent_mode","parent_state","path"] and
                ((.path | type) == "string") and (.path | test("^ifl-ios-standards/")) and
                (.path | test("(^|/)[.][.]?(/|$)") | not) and
                (.path | test("//") | not) and
                (.path | test("[[:cntrl:]]") | not) and
                (.disposition == "DELETE_07.0" or .disposition == "REWRITE_07.0" or .disposition == "CREATE_07.0") and
                (if .parent_state == "present" then
                    (.parent_blob | test("^[0-9a-f]{40}$")) and (.parent_mode == "100644" or .parent_mode == "100755")
                 else .parent_state == "absent" and .parent_blob == "-" and .parent_mode == "-" end) and
                (if .final_state == "present" then
                    (.final_blob | test("^[0-9a-f]{40}$")) and (.final_mode == "100644" or .final_mode == "100755")
                 else .final_state == "absent" and .final_blob == "-" and .final_mode == "-" end) and
                (if .disposition == "DELETE_07.0" then .parent_state == "present" and .final_state == "absent"
                 elif .disposition == "REWRITE_07.0" then .parent_state == "present" and .final_state == "present"
                 else .parent_state == "absent" and .final_state == "present" end))
        ' "$manifest" >/dev/null 2>&1; then
            add_violation "manifest:contract"; manifest_valid=0
        fi
    fi
    [ "$current_head" = "$expected_parent" ] || add_violation "manifest:current-head"

    if ! awk -F'`' '
        /^## Exact R[+] audit\/history closure/ { exit }
        /^- `ifl-ios-standards\// { path = $2 }
        {
            for (field = 2; field <= NF; field += 2) {
                if ($field ~ /^(DELETE_07[.]0|REWRITE_07[.]0|CREATE_07[.]0)$/ && path != "") {
                    print path "\t" $field
                    path = ""
                }
            }
        }
    ' "$inventory" >"$scratch/expected-unsorted"; then
        add_violation "manifest:inventory-parse"; : >"$scratch/expected-unsorted"
    fi
    LC_ALL=C sort "$scratch/expected-unsorted" >"$scratch/expected" ||
        add_violation "manifest:inventory-sort"
    expected_count=$(wc -l <"$scratch/expected" | tr -d ' ')
    expected_unique=$(cut -f1 "$scratch/expected" | LC_ALL=C sort -u | wc -l | tr -d ' ')
    [ "$expected_count" = 123 ] || add_violation "manifest:inventory-entry-count"
    [ "$expected_unique" = 123 ] || add_violation "manifest:inventory-path-uniqueness"

    if [ "$manifest_valid" -eq 1 ]; then
        jq -r '.entries[] | [.path,.disposition] | @tsv' "$manifest" >"$scratch/manifest-paths" ||
            add_violation "manifest:entry-extraction"
        cmp -s "$scratch/expected" "$scratch/manifest-paths" ||
            add_violation "manifest:inventory-path-equality"
        jq -r '.entries[] | [.path,.disposition,.parent_state,.parent_blob,.parent_mode,.final_state,.final_blob,.final_mode] | @tsv' \
            "$manifest" >"$scratch/manifest-entries" || add_violation "manifest:entry-extraction"
        while IFS=$'\t' read -r path disposition parent_state parent_blob parent_mode \
            final_state final_blob final_mode
        do
            [ -n "$path" ] || continue
            path_has_symlink_component "$path" && add_violation "manifest:symlink-component:$path"
            parent_line=$(git -C "$repository" ls-tree "$expected_parent" -- "$path" 2>/dev/null)
            parent_status=$?
            if [ "$parent_status" -ne 0 ]; then
                add_violation "manifest:parent-observation:$path"
            elif [ -n "$parent_line" ]; then
                actual_parent_mode=${parent_line%% *}
                parent_tail=${parent_line#* }
                actual_parent_type=${parent_tail%% *}
                parent_tail=${parent_tail#* }
                actual_parent_blob=${parent_tail%%$'\t'*}
                [ "$actual_parent_type" = blob ] || add_violation "manifest:parent-type:$path"
                [ "$parent_state" = present ] || add_violation "manifest:parent-state:$path"
                [ "$parent_blob" = "$actual_parent_blob" ] || add_violation "manifest:parent-blob:$path"
                [ "$parent_mode" = "$actual_parent_mode" ] || add_violation "manifest:parent-mode:$path"
            else
                [ "$parent_state" = absent ] || add_violation "manifest:parent-state:$path"
                [ "$parent_blob" = "-" ] || add_violation "manifest:parent-blob:$path"
                [ "$parent_mode" = "-" ] || add_violation "manifest:parent-mode:$path"
            fi
            candidate="$repository/$path"
            case "$disposition" in
                DELETE_07.0)
                    [ ! -e "$candidate" ] && [ ! -L "$candidate" ] ||
                        add_violation "manifest:expected-absent:$path" ;;
                REWRITE_07.0|CREATE_07.0)
                    if [ -L "$candidate" ]; then
                        add_violation "manifest:final-symlink:$path"
                    elif [ ! -f "$candidate" ]; then
                        add_violation "manifest:expected-regular:$path"
                    elif [ ! -r "$candidate" ]; then
                        add_violation "manifest:final-unreadable:$path"
                    else
                        actual_final_blob=$(git -C "$repository" hash-object "$path" 2>/dev/null)
                        [ -n "$actual_final_blob" ] && [ "$actual_final_blob" = "$final_blob" ] ||
                            add_violation "manifest:final-blob:$path"
                        actual_final_mode=100644
                        [ ! -x "$candidate" ] || actual_final_mode=100755
                        [ "$actual_final_mode" = "$final_mode" ] ||
                            add_violation "manifest:final-mode:$path"
                    fi ;;
                *) add_violation "manifest:disposition:$path" ;;
            esac
        done <"$scratch/manifest-entries"
    fi

    git -C "$repository" diff --name-only -z --no-renames "$expected_parent" -- . \
        >"$scratch/changed-tracked" || {
            add_violation "manifest:changed-set-observation"; : >"$scratch/changed-tracked"
        }
    git -C "$repository" ls-files -z --others --exclude-standard -- . \
        >"$scratch/changed-untracked" || {
            add_violation "manifest:changed-set-observation"; : >"$scratch/changed-untracked"
        }
    : >"$scratch/changed-lines"
    for source in "$scratch/changed-tracked" "$scratch/changed-untracked"; do
        while IFS= read -r -d '' changed_path; do
            case "$changed_path" in .git|.git/*|.superpowers|.superpowers/*) continue ;; esac
            if has_control "$changed_path"; then
                add_violation "manifest:unsafe-changed-path"
            else
                printf '%s\n' "$changed_path" >>"$scratch/changed-lines" ||
                    invalid "cannot record changed path"
            fi
        done <"$source"
    done
    LC_ALL=C sort -u "$scratch/changed-lines" >"$scratch/changed" ||
        add_violation "manifest:changed-set-sort"
    cut -f1 "$scratch/expected" | LC_ALL=C sort >"$scratch/expected-paths" ||
        add_violation "manifest:expected-path-sort"
    cmp -s "$scratch/expected-paths" "$scratch/changed" ||
        add_violation "manifest:changed-path-equality"

    tracked_diff_paths=()
    create_diff_paths=()
    tracked_diff_count=0
    create_diff_count=0
    diff_count=0
    while IFS=$'\t' read -r diff_path diff_disposition; do
        [ -n "$diff_path" ] || continue
        case "$diff_disposition" in
            CREATE_07.0)
                create_diff_paths[$create_diff_count]=$diff_path
                create_diff_count=$((create_diff_count + 1)) ;;
            *)
                tracked_diff_paths[$tracked_diff_count]=$diff_path
                tracked_diff_count=$((tracked_diff_count + 1)) ;;
        esac
        diff_count=$((diff_count + 1))
    done <"$scratch/expected"
    if [ "$diff_count" -ne 123 ]; then
        add_violation "manifest:diff-check-path-count"
    else
        diff_check_failed=0
        if [ "$tracked_diff_count" -gt 0 ]; then
            git -C "$repository" diff --check "$expected_parent" -- "${tracked_diff_paths[@]}" \
                >"$scratch/diff-check-tracked" 2>&1
            tracked_diff_status=$?
            if [ "$tracked_diff_status" -ne 0 ] || [ -s "$scratch/diff-check-tracked" ]; then
                diff_check_failed=1
            fi
        fi
        create_diff_index=0
        while [ "$create_diff_index" -lt "$create_diff_count" ]; do
            create_diff_path=${create_diff_paths[$create_diff_index]}
            git -C "$repository" diff --no-index --check -- /dev/null \
                "$repository/$create_diff_path" >"$scratch/diff-check-create" 2>&1
            create_diff_status=$?
            if [ -s "$scratch/diff-check-create" ]; then
                diff_check_failed=1
            else
                case "$create_diff_status" in
                    0|1) ;;
                    *) add_violation "manifest:diff-check-observation:$create_diff_path"; diff_check_failed=1 ;;
                esac
            fi
            create_diff_index=$((create_diff_index + 1))
        done
        [ "$diff_check_failed" -eq 0 ] || add_violation "manifest:diff-check"
    fi
fi

LC_ALL=C sort -u "$violations" -o "$violations" || invalid "cannot finalize diagnostics"
violation_count=$(wc -l <"$violations" | tr -d ' ')
if [ "$violation_count" -eq 0 ]; then
    result_status=conformant; exit_code=0
else
    result_status=nonconformant; exit_code=1
fi

if [ "$format" = json ]; then
    violations_json=$(jq -Rsc 'split("\n") | map(select(length > 0))' "$violations") ||
        invalid "cannot encode diagnostics"
    if [ -n "$manifest_sha" ]; then
        manifest_json=$(jq -cn --arg value "$manifest_sha" '$value')
    else
        manifest_json=null
    fi
    jq -cSn \
        --arg checkpoint 07.0 \
        --arg phase "${phase:-conformance}" \
        --arg status "$result_status" \
        --argjson manifest_sha256 "$manifest_json" \
        --argjson negative_fixture_rejected "$negative_fixture_rejected" \
        --argjson violation_count "$violation_count" \
        --argjson violations "$violations_json" \
        '{checkpoint:$checkpoint,manifest_sha256:$manifest_sha256,negative_fixture_rejected:$negative_fixture_rejected,phase:$phase,status:$status,violation_count:$violation_count,violations:$violations}'
else
    printf '%s: checkpoint 07.0 %s (%s violation(s); negative fixture rejected: %s)\n' \
        "$result_status" "${phase:-conformance}" "$violation_count" "$negative_fixture_rejected"
    while IFS= read -r violation; do printf '  - %s\n' "$violation"; done <"$violations"
fi
exit "$exit_code"
