#!/bin/bash
# Sets up a Claude Code on the web container: R, the graphics libraries ragg
# needs, Quarto for site previews, and the packages pinned in renv.lock.
# Safe to rerun: each step is skipped when already done.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

quarto_version="1.10.18"  # keep in step with .github/workflows/publish.yml

if ! command -v Rscript >/dev/null; then
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends r-base-core \
    libfreetype6 libpng16-16t64 libtiff6 libjpeg-turbo8 libwebp7 libwebpmux3 \
    libharfbuzz0b libfribidi0 fonts-dejavu-core >/dev/null
fi

if [ "$(quarto --version 2>/dev/null || true)" != "$quarto_version" ]; then
  deb="$(mktemp --suffix=.deb)"
  curl -sSL -o "$deb" \
    "https://github.com/quarto-dev/quarto-cli/releases/download/v${quarto_version}/quarto-${quarto_version}-linux-amd64.deb"
  dpkg -i "$deb" >/dev/null
  rm -f "$deb"
fi

# Prebuilt Linux binaries from Posit; compiling from CRAN source takes far longer.
export RENV_CONFIG_REPOS_OVERRIDE="https://p3m.dev/cran/__linux__/noble/latest"
echo "export RENV_CONFIG_REPOS_OVERRIDE=\"$RENV_CONFIG_REPOS_OVERRIDE\"" >> "$CLAUDE_ENV_FILE"

cd "$CLAUDE_PROJECT_DIR"
Rscript -e 'renv::restore(prompt = FALSE)' >/dev/null
