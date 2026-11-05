#!/usr/bin/env sh
# Runs on the host: starts a small HTTP listener, runs a k6 test of five
# requests against it and checks the summary k6 exported counts all five,
# each answered 200. Then points the same test at a closed port and checks
# k6 fails it on its threshold. CI pipes it in with podman exec.
set -eu
k6 version

# The listener is Python's, so the test images get python3 for the check.
command -v python3 >/dev/null || {
  if command -v apt-get >/dev/null; then
    apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 >/dev/null
  else
    dnf -y -q install python3
  fi
}

dir=$(mktemp -d)
trap 'kill "$pid" 2>/dev/null || true; rm -rf "$dir"' EXIT
echo 'hello from conn3x' > "$dir/index.html"
python3 -m http.server 18080 --bind 127.0.0.1 --directory "$dir" >/dev/null 2>&1 &
pid=$!
for _ in $(seq 20); do
  curl -sf http://127.0.0.1:18080/ >/dev/null && break
  sleep 0.5
done

cat > "$dir/test.js" <<'JS'
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  vus: 1,
  iterations: 5,
  thresholds: { checks: ['rate==1'] },
};

export default function () {
  const res = http.get(__ENV.TARGET);
  check(res, {
    'status is 200': (r) => r.status === 200,
    'body is the page': (r) => r.body.includes('hello from conn3x'),
  });
}
JS

k6 run --quiet --no-usage-report -e TARGET=http://127.0.0.1:18080/ \
  --summary-export "$dir/summary.json" "$dir/test.js"

python3 - "$dir/summary.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))["metrics"]
print("http_reqs:", m["http_reqs"]["count"], "checks passed:", m["checks"]["passes"], "failed:", m["checks"]["fails"])
assert m["http_reqs"]["count"] == 5, "k6 didn't make five requests"
assert m["checks"]["passes"] == 10 and m["checks"]["fails"] == 0, "a check failed"
assert m["http_req_failed"]["value"] == 0, "a request failed"
PY

# k6 exits 99 when a threshold fails.
rc=0
k6 run --quiet --no-usage-report -e TARGET=http://127.0.0.1:18081/ "$dir/test.js" >/dev/null 2>&1 || rc=$?
if [ "$rc" != 99 ]; then
  echo "Against a closed port, k6 exited $rc, not 99 for a failed threshold." >&2
  exit 1
fi
echo "k6 passed the test against the listener and failed it against a closed port."
