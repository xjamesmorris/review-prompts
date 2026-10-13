#!/bin/bash
#
# Agent setup script for GitHub Copilot CLI
# (https://docs.github.com/copilot/how-tos/copilot-cli).
#
# Sourced by setup.sh to configure where skills and slash commands are
# installed. Exports the install paths and skill filename expected by the
# agent; additional per-agent setup steps (if any) can be added here.
#
# Copilot CLI discovers personal skills as ~/.copilot/skills/<name>/SKILL.md,
# or $COPILOT_HOME/skills when COPILOT_HOME is set (verify with
# 'copilot skill list').  It has no personal slash-command files: a skill is
# invoked as /<name>, interactively or via 'copilot -p "/<name> ..."', so
# the commands are installed as skills too via COMMANDS_AS_SKILLS.

_COPILOT_CONFIG_DIR="${COPILOT_HOME:-$HOME/.copilot}"

export SKILL_BASE_DIR="$_COPILOT_CONFIG_DIR/skills"
export COMMANDS_DIR="$_COPILOT_CONFIG_DIR/skills"
export SKILL_FILE_NAME="SKILL.md"
export COMMANDS_AS_SKILLS=1
