# init uv
if command -v uv >/dev/null 2>&1; then
  eval "$(uv generate-shell-environment zsh 2>/dev/null)" || true
fi
