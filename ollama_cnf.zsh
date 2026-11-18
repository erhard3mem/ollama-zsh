# ollama-cnf.zsh — send every "command not found" to Ollama and print the answer to stdout
#
# Install:  put this file somewhere, e.g. ~/.config/zsh/ollama-cnf.zsh,
#           and add this as the LAST line of ~/.zshrc:
#               source ~/.config/zsh/ollama-cnf.zsh
#
# Settings (override in ~/.zshrc before sourcing, or export at any time):
: ${OLLAMA_CNF_MODEL:=gemma:latest}            # model to use
: ${OLLAMA_CNF_HOST:=http://localhost:11434}   # Ollama service URL
: ${OLLAMA_CNF_ENABLED:=1}                     # set to 0 to switch off temporarily
: ${OLLAMA_CNF_SYSTEM:="Short response. No markdown."}

autoload -Uz add-zsh-hook

# Remember the raw line exactly as typed (quotes, globs, pipes, ...)
_ollama_cnf_preexec() { typeset -g _OLLAMA_CNF_LINE=$1 }
add-zsh-hook preexec _ollama_cnf_preexec

command_not_found_handler() {
  # Fallback: not interactive, switched off, or already inside the handler
  if [[ ! -o interactive || $OLLAMA_CNF_ENABLED != 1 || -n $_OLLAMA_CNF_ACTIVE ]]; then
    print -u2 "zsh: command not found: $1"
    return 127
  fi
  local _OLLAMA_CNF_ACTIVE=1

  # Everything typed: raw line if available, otherwise cmd + args
  local input=${_OLLAMA_CNF_LINE:-$*}

  print -u2 -P "%F{8}zsh: command not found: $1 → asking $OLLAMA_CNF_MODEL …%f"

  if (( $+commands[curl] && $+commands[jq] )); then
    # Stream via the REST API (no spinner, clean stdout)
    jq -n --arg m "$OLLAMA_CNF_MODEL" --arg s "$OLLAMA_CNF_SYSTEM" --arg p "$input" \
          '{model:$m, system:$s, prompt:$p}' \
      | curl -sN --fail "$OLLAMA_CNF_HOST/api/generate" -d @- \
      | jq -rj '.response // empty'
    local rc=$pipestatus[2]
    print
    (( rc )) && print -u2 "ollama-cnf: request failed (is the service running at $OLLAMA_CNF_HOST?)"
  elif (( $+commands[ollama] )); then
    # Fallback: the ollama CLI
    ollama run --nowordwrap "$OLLAMA_CNF_MODEL" "$OLLAMA_CNF_SYSTEM

Command typed: $input"
  else
    print -u2 "ollama-cnf: neither curl+jq nor ollama found"
  fi

  return 127
}

# Quick toggles
ai-on()  { OLLAMA_CNF_ENABLED=1; print "ollama-cnf: on ($OLLAMA_CNF_MODEL)" }
ai-off() { OLLAMA_CNF_ENABLED=0; print "ollama-cnf: off" }
