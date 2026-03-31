#!/usr/bin/env python3

import json
import sys

REQUIRED_PHRASES = (
    "I ABSOLUTELY CONFIRM THAT ALL TASKS ARE COMPLETE AND ALL GOALS HAVE BEEN ACHIEVED",
    "I ABSOLUTELY CONFIRM THAT IT IS IMPOSSIBLE TO COMPLETE ALL TASKS OR ACHIEVE ALL GOALS UNDER ANY CIRCUMSTANCES",
    "THE USER DID NOT SPECIFY ANY TASK",
)


def allowed_phrases_text() -> str:
    return ", ".join(f'"{phrase}"' for phrase in REQUIRED_PHRASES)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        json.dump(
            {
                "decision": "block",
                "reason": (
                    "The Stop hook could not parse the current turn data. Do not end the current turn; "
                    "you may stop only if your final reply contains one of the following phrases verbatim: "
                    f"{allowed_phrases_text()}."
                ),
            },
            sys.stdout,
            ensure_ascii=False,
        )
        sys.stdout.write("\n")
        return 0

    last_message = payload.get("last_assistant_message") or ""
    if any(phrase in last_message for phrase in REQUIRED_PHRASES):
        json.dump({"continue": True}, sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        return 0

    hook_active = payload.get("stop_hook_active", False)
    reminder = (
        "The Stop hook has already continued you once; "
        if hook_active
        else "Do not end the current turn; "
    )
    json.dump(
        {
            "decision": "block",
            "reason": (
                f"{reminder}your final reply must contain one of the following phrases verbatim: "
                f"{allowed_phrases_text()}."
                " You may stop only when you are completely certain the task is finished, "
                "or absolutely certain it cannot be completed."
            ),
        },
        sys.stdout,
        ensure_ascii=False,
    )
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
