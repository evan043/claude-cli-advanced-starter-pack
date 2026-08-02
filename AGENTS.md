# AGENTS

<!-- CCASP-CODEX-SLASH-ROUTER:START -->
## CCASP Codex Slash Router

When the user enters a message that starts with `/`, treat it as a CCASP command alias.

Command handling rules:
- Parse the first token as the command id (remove leading `/`).
- Read `.codex/prompts/<command-id>.md` if it exists.
- Treat that prompt file as the primary instruction set for the task.
- Apply cross-runtime compatibility: if a prompt references Claude-only tools, use Codex equivalents (ask user directly for AskUserQuestion, use web.search/open for WebSearch/WebFetch, and shell/file tools for Read/Write).
- Treat remaining user text after the command as command arguments/context.
- If the prompt file does not exist, list available commands from `.codex/prompts/*.md` and ask the user to choose one.

Do not ignore valid `/command` messages and do not respond with "slash commands are unsupported" when a mapped prompt exists.
<!-- CCASP-CODEX-SLASH-ROUTER:END -->
