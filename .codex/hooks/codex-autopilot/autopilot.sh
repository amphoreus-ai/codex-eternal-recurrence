#!/bin/sh

emit_block() { jq -Rn --arg reason "$1" '{"decision":"block","reason":$reason}'; }
emit_continue() { printf '{"continue":true}\n'; }
emit_fail() { jq -Rn --arg reason "$1" '{"continue":false,"stopReason":$reason}'; }

extract_user_messages_from_transcript() {
  jq -R -s -r '
    def text:
      if . == null then ""
      elif type == "string" then .
      elif type == "array" then map(text) | join("")
      elif type == "object" then
        if has("content") then .content | text
        elif has("text") then .text | text
        elif has("message") then .message | text
        elif has("delta") then .delta | text
        elif has("item") then .item | text
        else ""
        end
      else tostring
      end;

    [split("\n")[]
      | select(length > 0)
      | fromjson?
      | .. | objects
      | select(.role? == "user")
      | (if has("content") then .content | text else text end)]
    | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
    | map(select(length > 0))
    | if length == 0 then "" else
        to_entries
        | map("User message " + ((.key + 1) | tostring) + ":\n" + .value)
        | join("\n\n")
      end
  '
}

hook_input=$(cat)

# 1. Read the last assistant message.
last_assistant_message=$(printf '%s' "$hook_input" | jq -r '.last_assistant_message // ""')

if [ -z "$last_assistant_message" ]; then
  emit_block "No assistant message found to judge. Please continue working"
  exit 0
fi

transcript_path=$(printf '%s' "$hook_input" | jq -r '.transcript_path // ""' 2>/dev/null)

if [ -z "$transcript_path" ] || [ "$transcript_path" = "null" ] || [ ! -f "$transcript_path" ]; then
  emit_fail "transcript_path is missing or invalid."
  exit 0
fi

user_messages=$(extract_user_messages_from_transcript < "$transcript_path" 2>/dev/null)

if [ -z "$user_messages" ]; then
  emit_fail "No user messages found."
  exit 0
fi

result_file=$(mktemp)
exec_dir=$(mktemp -d)
schema_file="$(cd "$(dirname "$0")" && pwd)/judge-schema.json"

trap 'rm -f "$result_file"; rm -rf "$exec_dir"' EXIT INT TERM

(cd "$exec_dir" && printf 'Assistant message:\n%s\n\nAll user messages:\n%s\n' "$last_assistant_message" "$user_messages" | codex exec \
  'You are a strict task-completion auditor. You will receive the latest assistant message and all user messages from a conversation between a user and a coding agent.

Determine whether the agent GENUINELY completed what the user asked. Rules:
- "complete": The message contains concrete evidence of real work (code changes, tool calls, concrete output) that matches the user request.
- "incomplete": The agent is stopping without finishing, or just claims completion without evidence. Reward hacking must be classified as incomplete.
- "failed": Agent tried multiple approaches but hit an insurmountable blocker.
- "suspended": Agent legitimately needs user input or authorization to continue.
- "waiting": Agent is waiting for an external event or process to complete before it can proceed.

Be skeptical. Use the assistant message and all user messages together. Look for concrete evidence, not just claims.' \
  --ephemeral --skip-git-repo-check \
  --output-schema "$schema_file" \
  -o "$result_file" >/dev/null 2>&1)

verdict=$(jq -r '.verdict // "incomplete"' "$result_file" 2>/dev/null)
reason=$(jq -r '.reason // "No reason provided."' "$result_file" 2>/dev/null)

case "$verdict" in
  complete|failed) emit_continue ;;
  suspended) emit_block "User is away and cannot respond. — Please think about what you can do next to make progress independently without waiting for user input." ;;
  incomplete) emit_block "Your task is not yet complete. Reason: $reason — Please continue working." ;;
  waiting) emit_block 'You are waiting for an external event or process. — Please estimate when you will be able to proceed, and wait with `sleep` at an appropriate interval.' ;;
esac
