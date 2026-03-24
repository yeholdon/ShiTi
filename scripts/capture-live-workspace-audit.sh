#!/usr/bin/env bash

set -euo pipefail

api_base_url="${SHITI_API_BASE_URL:-http://127.0.0.1:3000}"
web_base_url="${SHITI_WEB_BASE_URL:-http://127.0.0.1:7445}"
username="${SHITI_AUDIT_USERNAME:-teacher_demo}"
password="${SHITI_AUDIT_PASSWORD:-demo-password}"
output_dir="${1:-/tmp/shiti-live-audit}"

mkdir -p "$output_dir"

bridge_payload_file="$(mktemp /tmp/shiti-live-audit-payload.XXXXXX.json)"
cleanup() {
  rm -f "$bridge_payload_file"
}
trap cleanup EXIT

python3 - "$api_base_url" "$username" "$password" "$bridge_payload_file" <<'PY'
import json
import sys
import urllib.request

api_base_url, username, password, output_path = sys.argv[1:]

login_request = urllib.request.Request(
    f"{api_base_url}/auth/login",
    data=json.dumps({"username": username, "password": password}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(login_request) as response:
    login = json.load(response)

tenants_request = urllib.request.Request(
    f"{api_base_url}/tenants",
    headers={"Authorization": f"Bearer {login['accessToken']}"},
)
with urllib.request.urlopen(tenants_request) as response:
    tenants = json.load(response)["tenants"]

organization = next(tenant for tenant in tenants if tenant["kind"] == "organization")

payload = {
    "session": json.dumps(
        {
            "userId": login["userId"],
            "username": login["username"],
            "accessLevel": login["accessLevel"],
            "accessToken": login["accessToken"],
            "tokenPreview": login["accessToken"],
        },
        ensure_ascii=False,
    ),
    "tenant": json.dumps(organization, ensure_ascii=False),
}

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False)
PY

capture_via_bridge() {
  local redirect_url="$1"
  local output_path="$2"
  python3 - "$web_base_url" "$bridge_payload_file" "$redirect_url" "$output_path" <<'PY'
import json
import subprocess
import sys
import urllib.parse

web_base_url, payload_file, redirect_url, output_path = sys.argv[1:]
with open(payload_file, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

bridge_url = web_base_url + "/auth_bridge.html?" + urllib.parse.urlencode(
    {
        "session": payload["session"],
        "tenant": payload["tenant"],
        "redirect": redirect_url,
    }
)

subprocess.run(
    [
        "/Users/honcy/Project/ShiTi/scripts/capture-edge-fullpage.sh",
        bridge_url,
        output_path,
    ],
    check=True,
)
PY
}

echo "Capturing live workspace audit into $output_dir"

capture_via_bridge \
  "${web_base_url}/#/" \
  "${output_dir}/home-live.png"

capture_via_bridge \
  "${web_base_url}/#/students/detail?studentId=student-3" \
  "${output_dir}/student-detail-live.png"

capture_via_bridge \
  "${web_base_url}/#/classes/detail?classId=class-3" \
  "${output_dir}/class-detail-live.png"

capture_via_bridge \
  "${web_base_url}/#/lessons/detail?lessonId=lesson-3" \
  "${output_dir}/lesson-detail-live.png"

capture_via_bridge \
  "${web_base_url}/#/documents/detail?documentId=80000000-0000-0000-0000-000000000001" \
  "${output_dir}/document-detail-live.png"

capture_via_bridge \
  "${web_base_url}/#/documents?focusDocumentId=80000000-0000-0000-0000-000000000001&flashMessage=%E5%B7%B2%E5%AE%9A%E4%BD%8D%E5%88%B0%E5%8A%9B%E5%AD%A6%E6%A8%A1%E5%9E%8B%E8%AE%B2%E4%B9%89%EF%BC%8C%E5%8F%AF%E7%BB%A7%E7%BB%AD%E6%95%B4%E7%90%86%E8%AF%BE%E5%A0%82%E8%B5%84%E6%96%99%E3%80%82&highlightTitle=%E5%BD%93%E5%89%8D%E8%AF%BE%E5%A0%82%E8%B5%84%E6%96%99&highlightDetail=%E5%8A%9B%E5%AD%A6%E6%A8%A1%E5%9E%8B%E8%AE%B2%E4%B9%89%E6%AD%A3%E6%89%BF%E6%8E%A5%E9%AB%98%E4%B8%80%E5%8A%9B%E5%AD%A6%E6%A8%A1%E5%9E%8B%E6%8B%86%E8%A7%A3%E8%AF%BE%E7%9A%84%E8%B5%84%E6%96%99%E5%AE%89%E6%8E%92%EF%BC%8C%E5%8F%AF%E7%BB%A7%E7%BB%AD%E8%A1%A5%E8%AE%B2%E4%B9%89%E3%80%81%E8%AF%95%E5%8D%B7%E5%92%8C%E8%AF%BE%E5%A0%82%E8%8A%82%E5%A5%8F%E3%80%82&feedbackBadgeLabel=%E8%AF%BE%E5%A0%82%E8%B5%84%E6%96%99" \
  "${output_dir}/documents-lesson-context-live.png"

echo "Audit screenshots:"
find "$output_dir" -maxdepth 1 -type f -name '*.png' | sort
