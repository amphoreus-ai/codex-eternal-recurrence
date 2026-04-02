#!/bin/sh

PHRASE_1='I ABSOLUTELY CONFIRM THAT ALL TASKS ARE COMPLETE AND ALL GOALS HAVE BEEN ACHIEVED, BECAUSE'
PHRASE_2='I ABSOLUTELY CONFIRM THAT IT IS IMPOSSIBLE TO COMPLETE ALL TASKS OR ACHIEVE ALL GOALS UNDER ANY CIRCUMSTANCES, BECAUSE'
PHRASE_3='THE USER DID NOT SPECIFY ANY TASK, BECAUSE'

allowed_phrases_text() {
  printf '%s' "$PHRASE_1 | $PHRASE_2 | $PHRASE_3"
}

emit_continue() {
  printf '%s\n' '{"continue":true}'
}

emit_block() {
  reason=$1
  printf '{"decision":"block","reason":"%s"}\n' "$reason"
}

block_reason() {
  printf '%s' "Re-check before stopping: either every requested task is perfectly complete and every goal is strictly satisfied, or completion is absolutely impossible. If more work is possible, continue. If you must stop, start your reply with exactly one of these phrases and then give a reason of at least 100 words: $(allowed_phrases_text). Do not misrepresent the state. Stop only when you can swear."
}

payload=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  emit_block "$(block_reason)"
  exit 0
fi

last_message=$(printf '%s' "$payload" | jq -r 'if type == "object" then (.last_assistant_message // "") else "" end | if type == "string" then . else "" end' 2>/dev/null)

case $last_message in
  *"$PHRASE_1"* | *"$PHRASE_2"* | *"$PHRASE_3"*)
    emit_continue
    exit 0
    ;;
esac

emit_block "$(block_reason)"
