#!/usr/bin/env bash

set -euo pipefail

api_base_url="${SHITI_API_BASE_URL:-http://127.0.0.1:3000}"
web_base_url="${SHITI_WEB_BASE_URL:-http://127.0.0.1:4111}"
username="${SHITI_AUDIT_USERNAME:-teacher_demo}"
password="${SHITI_AUDIT_PASSWORD:-demo-password}"
output_dir="${1:-/tmp/shiti-live-write-audit}"
capture_post_load_delay_ms="${CAPTURE_FULLPAGE_POST_LOAD_DELAY_MS:-3500}"
capture_blank_retries="${CAPTURE_FULLPAGE_BLANK_RETRIES:-6}"

proxyless_env=(
  env
  -u http_proxy
  -u https_proxy
  -u HTTP_PROXY
  -u HTTPS_PROXY
  -u all_proxy
  -u ALL_PROXY
)

mkdir -p "$output_dir"

payload_file="$(mktemp /tmp/shiti-live-write-audit-payload.XXXXXX).json"
storage_state_file="$(mktemp /tmp/shiti-live-write-audit-storage.XXXXXX).json"
cleanup() {
  rm -f "$payload_file" "$storage_state_file"
}
trap cleanup EXIT

"${proxyless_env[@]}" python3 - "$api_base_url" "$username" "$password" "$payload_file" <<'PY'
import json
import sys
import time
import urllib.parse
import urllib.request

api_base_url, username, password, output_path = sys.argv[1:]
stamp = str(int(time.time()))

def request(method, path, token=None, tenant_code=None, body=None):
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if tenant_code:
        headers["x-tenant-code"] = tenant_code
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    req = urllib.request.Request(
        f"{api_base_url}{path}",
        headers=headers,
        data=data,
        method=method,
    )
    with urllib.request.urlopen(req) as response:
        return json.load(response)

login = request(
    "POST",
    "/auth/login",
    body={"username": username, "password": password},
)
tenants = request("GET", "/tenants", token=login["accessToken"])["tenants"]
organization = next(tenant for tenant in tenants if tenant["kind"] == "organization")
tenant_code = organization["code"]

created_class = request(
    "POST",
    "/classes",
    token=login["accessToken"],
    tenant_code=tenant_code,
    body={
        "name": f"审计班级-{stamp}",
        "stageLabel": "初中 · 九年级",
        "teacherLabel": "主讲：审计老师",
        "textbookLabel": "浙教版",
        "focusLabel": "讲义整理",
    },
)["class"]

updated_class = request(
    "PATCH",
    f"/classes/{created_class['id']}",
    token=login["accessToken"],
    tenant_code=tenant_code,
    body={
        "name": f"审计班级（已更新）-{stamp}",
        "stageLabel": "初中 · 九年级",
        "teacherLabel": "主讲：更新老师",
        "textbookLabel": "人教版",
        "focusLabel": "课堂复盘",
    },
)["class"]

created_student = request(
    "POST",
    "/students",
    token=login["accessToken"],
    tenant_code=tenant_code,
    body={
        "name": f"审计学生-{stamp}",
        "gradeLabel": "初中 · 九年级下",
        "subjectLabel": "数学",
        "textbookLabel": "浙教版",
        "className": updated_class["name"],
    },
)["student"]

updated_student = request(
    "PATCH",
    f"/students/{created_student['id']}",
    token=login["accessToken"],
    tenant_code=tenant_code,
    body={
        "name": f"审计学生（已更新）-{stamp}",
        "gradeLabel": "初中 · 九年级下",
        "subjectLabel": "数学",
        "textbookLabel": "人教版",
        "className": updated_class["name"],
    },
)["student"]

created_lesson = request(
    "POST",
    "/lessons",
    token=login["accessToken"],
    tenant_code=tenant_code,
    body={
        "title": f"审计课堂-{stamp}",
        "teacherLabel": "主讲：审计老师",
        "scheduleLabel": "周五 19:00",
        "classScopeLabel": updated_class["name"],
    },
)["lesson"]

updated_lesson = request(
    "PATCH",
    f"/lessons/{created_lesson['id']}",
    token=login["accessToken"],
    tenant_code=tenant_code,
    body={
        "title": f"审计课堂（已更新）-{stamp}",
        "teacherLabel": "主讲：更新老师",
        "scheduleLabel": "周六 14:00",
        "classScopeLabel": updated_class["name"],
    },
)["lesson"]

payload = {
    "storage": {
        "flutter.auth_session": json.dumps(
            {
                "userId": login["userId"],
                "username": login["username"],
                "accessLevel": login["accessLevel"],
                "accessToken": login["accessToken"],
                "tokenPreview": login["accessToken"],
            },
            ensure_ascii=False,
        ),
        "flutter.active_tenant": json.dumps(organization, ensure_ascii=False),
    },
    "routes": {},
}

def build_hash_route(path, params):
    return f"/#{path}?{urllib.parse.urlencode(params)}"

payload["routes"] = {
    "students-created-live": build_hash_route(
        "/students",
        {
            "focusStudentId": updated_student["id"],
            "flashMessage": f"已创建并聚焦 {updated_student['name']}。",
            "highlightTitle": "当前新建学生",
            "highlightDetail": f"{updated_student['name']} 已写入真实数据，可继续补充资料与课堂承接。",
            "feedbackBadgeLabel": "新建学生",
        },
    ),
    "student-detail-updated-live": build_hash_route(
        "/students/detail",
        {
            "studentId": updated_student["id"],
            "flashMessage": f"已更新 {updated_student['name']} 的学生档案。",
        },
    ),
    "classes-created-live": build_hash_route(
        "/classes",
        {
            "focusClassId": updated_class["id"],
            "flashMessage": f"已创建并聚焦 {updated_class['name']}。",
            "highlightTitle": "当前新建班级",
            "highlightDetail": f"{updated_class['name']} 已写入真实数据，可继续补充成员、课堂和资料。",
            "feedbackBadgeLabel": "新建班级",
        },
    ),
    "class-detail-updated-live": build_hash_route(
        "/classes/detail",
        {
            "classId": updated_class["id"],
            "flashMessage": f"已更新 {updated_class['name']} 的班级档案。",
        },
    ),
    "lessons-created-live": build_hash_route(
        "/lessons",
        {
            "focusLessonId": updated_lesson["id"],
            "flashMessage": f"已创建并聚焦 {updated_lesson['title']}。",
            "highlightTitle": "当前新建课堂",
            "highlightDetail": f"{updated_lesson['title']} 已写入真实数据，可继续补充资料、反馈和任务。",
            "feedbackBadgeLabel": "新建课堂",
        },
    ),
    "lesson-detail-updated-live": build_hash_route(
        "/lessons/detail",
        {
            "lessonId": updated_lesson["id"],
            "flashMessage": f"已更新 {updated_lesson['title']} 的课堂档案。",
        },
    ),
}

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
PY

"${proxyless_env[@]}" python3 - "$payload_file" "$storage_state_file" <<'PY'
import json
import sys

payload_path, output_path = sys.argv[1:]
with open(payload_path, "r", encoding="utf-8") as source:
    payload = json.load(source)
with open(output_path, "w", encoding="utf-8") as target:
    json.dump(payload["storage"], target, ensure_ascii=False, indent=2)
PY

while IFS=$'\t' read -r name route; do
  [[ -n "$name" ]] || continue
  echo "capturing ${name}..."
  "${proxyless_env[@]}" \
    CAPTURE_FULLPAGE_POST_LOAD_DELAY_MS="$capture_post_load_delay_ms" \
    CAPTURE_FULLPAGE_BLANK_RETRIES="$capture_blank_retries" \
    /Users/honcy/Project/ShiTi/scripts/capture-edge-fullpage.sh \
    "${web_base_url}${route}" \
    "${output_dir}/${name}.png" \
    "$storage_state_file" >/dev/null
done < <(
  "${proxyless_env[@]}" python3 - "$payload_file" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

for name, route in payload["routes"].items():
    print(f"{name}\t{route}")
PY
)

echo "$output_dir"
