#!/usr/bin/env bash
# Builds the Next.js landing page and publishes it to the gh-pages branch
# (https://opulencecircle82.github.io/FAP/). The app is Android-only; the
# web simulator is no longer published.
set -euo pipefail
cd "$(dirname "$0")"
export MSYS_NO_PATHCONV=1

rm -rf landing/public/simulator
(cd landing && npm ci && npm run build)
touch landing/out/.nojekyll   # keep the _next/ folder on GitHub Pages

# Commit on top of the current gh-pages (a force-push of fresh history is
# rejected by GitHub with "Internal Server Error").
tmp=.deploy-gh-pages
rm -rf "$tmp"
git clone -q --depth 1 -b gh-pages "$(git remote get-url origin)" "$tmp"
git -C "$tmp" rm -rq .
cp -r landing/out/. "$tmp"
git -C "$tmp" add -A
git -C "$tmp" commit -q -m "Deploy landing page"
git -C "$tmp" push -q origin gh-pages
rm -rf "$tmp"
echo "Deployed to https://opulencecircle82.github.io/FAP/"
