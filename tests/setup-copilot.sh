#!/bin/bash
#
# Test './setup.sh copilot <project>' for every project, installing into a
# throwaway HOME/COPILOT_HOME.  When the copilot CLI is available, also check
# that it discovers the installed skills.
#
# Usage: tests/setup-copilot.sh

set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# Print the YAML frontmatter of $1 (the lines between the leading '---' and
# the next '---'); fail if the file does not start with frontmatter.
frontmatter() {
    awk 'NR == 1 { if ($0 != "---") exit 1; next }
         $0 == "---" { closed = 1; exit }
         { print }
         END { if (!closed) exit 1 }' "$1"
}

# Copilot requires a kebab-case name (max 64 chars) matching the skill
# directory, and a description of at most 1024 chars.
assert_valid_skill() {
    local skill_dir="$1"
    local skill_file="$skill_dir/SKILL.md"
    local fm name description

    [ -f "$skill_file" ] || fail "missing $skill_file"
    fm="$(frontmatter "$skill_file")" || fail "$skill_file has no YAML frontmatter"

    name="$(printf '%s\n' "$fm" | sed -n 's/^name: *//p')"
    [ "$name" = "$(basename "$skill_dir")" ] || \
        fail "$skill_file: name '$name' does not match its directory"
    [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] && [ "${#name}" -le 64 ] || \
        fail "$skill_file: invalid skill name '$name'"

    description="$(printf '%s\n' "$fm" | sed -n 's/^description: *//p')"
    [ -n "$description" ] && [ "${#description}" -le 1024 ] || \
        fail "$skill_file: missing or overlong description"
}

checksums() {
    (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum)
}

projects=()
for skill in "$REPO_DIR"/*/skills/*.md; do
    project="$(basename "$(dirname "$(dirname "$skill")")")"
    if [ "$(basename "$skill" .md)" = "$project" ]; then
        projects+=("$project")
    fi
done
[ "${#projects[@]}" -gt 0 ] || fail "no projects found"

for project in "${projects[@]}"; do
    home="$TEST_ROOT/$project/home"
    copilot_home="$TEST_ROOT/$project/copilot-home"
    output="$TEST_ROOT/$project/setup.out"
    skills="$copilot_home/skills"
    mkdir -p "$home"

    HOME="$home" COPILOT_HOME="$copilot_home" \
        "$REPO_DIR/setup.sh" copilot "$project" > "$output"

    assert_valid_skill "$skills/$project"
    grep -Fq "$REPO_DIR/$project" "$skills/$project/SKILL.md" || \
        fail "$project skill does not contain the expanded prompt path"

    expected=("$project")
    for source_command in "$REPO_DIR/$project/slash-commands/"*.md; do
        command_name="$(basename "$source_command" .md)"
        expected+=("$command_name")
        assert_valid_skill "$skills/$command_name"
        grep -Fqx "  /$command_name" "$output" || \
            fail "setup output does not list /$command_name"
    done

    if grep -R -n '{{[A-Z_][A-Z_]*}}' "$skills"; then
        fail "unexpanded placeholder in installed $project skills"
    fi
    if [ -e "$home/.copilot" ] || [ -e "$home/.agents" ]; then
        fail "$project install ignored COPILOT_HOME"
    fi

    checksums "$skills" > "$TEST_ROOT/$project/before.sha256"
    HOME="$home" COPILOT_HOME="$copilot_home" \
        "$REPO_DIR/setup.sh" copilot "$project" > /dev/null
    checksums "$skills" > "$TEST_ROOT/$project/after.sha256"
    cmp -s "$TEST_ROOT/$project/before.sha256" "$TEST_ROOT/$project/after.sha256" || \
        fail "$project installation is not idempotent"

    if command -v copilot > /dev/null 2>&1; then
        listing="$(cd "$TEST_ROOT" && env -u COPILOT_SKILLS_DIRS \
            HOME="$home" COPILOT_HOME="$copilot_home" \
            timeout 120 copilot skill list 2>&1)" || \
            fail "'copilot skill list' failed for $project: $listing"
        for name in "${expected[@]}"; do
            grep -q "^  $name - " <<< "$listing" || \
                fail "copilot does not list the $name skill"
        done
    fi
done

default_home="$TEST_ROOT/default-home"
mkdir -p "$default_home"
env -u COPILOT_HOME HOME="$default_home" \
    "$REPO_DIR/setup.sh" copilot kernel > /dev/null
assert_valid_skill "$default_home/.copilot/skills/kernel"
assert_valid_skill "$default_home/.copilot/skills/kreview"

if ! command -v copilot > /dev/null 2>&1; then
    echo "Note: copilot CLI not found, skipped the skill discovery check"
fi
echo "Copilot setup tests passed"
