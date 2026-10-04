#!/usr/bin/env bash
# Builds the web simulator + Next.js landing page and publishes them to the
# gh-pages branch (https://opulencecircle82.github.io/FAP/).
set -euo pipefail
cd "$(dirname "$0")"
export MSYS_NO_PATHCONV=1

(cd a320_fap && flutter build web --release --base-href /FAP/simulator/)
rm -rf landing/public/simulator
cp -r a320_fap/build/web landing/public/simulator

(cd landing && npm ci && npm run build)
touch landing/out/.nojekyll   # keep the _next/ folder on GitHub Pages

tmp=.deploy-gh-pages
rm -rf "$tmp" && mkdir "$tmp"
cp -r landing/out/. "$tmp"
git -C "$tmp" init -q -b gh-pages
git -C "$tmp" add -A
git -C "$tmp" commit -q -m "Deploy landing page"
git -C "$tmp" push -f "$(git remote get-url origin)" gh-pages
rm -rf "$tmp"
echo "Deployed to https://opulencecircle82.github.io/FAP/"
