#!/usr/bin/env bash

set -euo pipefail

api_base_url="${SHITI_API_BASE_URL:-http://127.0.0.1:3000}"
web_base_url="${SHITI_WEB_BASE_URL:-http://127.0.0.1:7445}"
username="${SHITI_AUDIT_USERNAME:-teacher_demo}"
password="${SHITI_AUDIT_PASSWORD:-demo-password}"
output_dir="${1:-/tmp/shiti-live-audit}"
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

bridge_payload_file="$(mktemp /tmp/shiti-live-audit-payload.XXXXXX).json"
storage_state_file="$(mktemp /tmp/shiti-live-audit-storage.XXXXXX).json"
cleanup() {
  rm -f "$bridge_payload_file"
  rm -f "$storage_state_file"
}
trap cleanup EXIT

"${proxyless_env[@]}" python3 - "$api_base_url" "$web_base_url" "$username" "$password" "$bridge_payload_file" <<'PY'
import json
import sys
import urllib.parse
import urllib.request

api_base_url, web_base_url, username, password, output_path = sys.argv[1:]

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

documents_request = urllib.request.Request(
    f"{api_base_url}/documents",
    headers={
        "Authorization": f"Bearer {login['accessToken']}",
        "x-tenant-code": organization["code"],
    },
)
with urllib.request.urlopen(documents_request) as response:
    documents = json.load(response)["documents"]

students_request = urllib.request.Request(
    f"{api_base_url}/students",
    headers={
        "Authorization": f"Bearer {login['accessToken']}",
        "x-tenant-code": organization["code"],
    },
)
with urllib.request.urlopen(students_request) as response:
    students = json.load(response)["students"]

classes_request = urllib.request.Request(
    f"{api_base_url}/classes",
    headers={
        "Authorization": f"Bearer {login['accessToken']}",
        "x-tenant-code": organization["code"],
    },
)
with urllib.request.urlopen(classes_request) as response:
    classes = json.load(response)["classes"]

lessons_request = urllib.request.Request(
    f"{api_base_url}/lessons",
    headers={
        "Authorization": f"Bearer {login['accessToken']}",
        "x-tenant-code": organization["code"],
    },
)
with urllib.request.urlopen(lessons_request) as response:
    lessons = json.load(response)["lessons"]

questions_request = urllib.request.Request(
    f"{api_base_url}/questions?include=tags,summary",
    headers={
        "Authorization": f"Bearer {login['accessToken']}",
        "x-tenant-code": organization["code"],
    },
)
with urllib.request.urlopen(questions_request) as response:
    questions = json.load(response)["questions"]

primary_document = documents[0]
primary_student = students[0]
primary_class = classes[0]
primary_lesson = lessons[0]
primary_question = questions[0]
primary_student_stage = primary_student["gradeLabel"].split("·")[0].strip()
primary_class_student = next(
    (student for student in students if student["classId"] == primary_class["id"]),
    primary_student,
)
primary_lesson_student = next(
    (
        student
        for student in students
        if student["id"] == primary_lesson.get("focusStudentId")
        or student["lessonId"] == primary_lesson["id"]
    ),
    primary_student,
)
primary_class_stage = primary_class["stageLabel"].split("·")[0].strip()
primary_lesson_stage = primary_lesson_student["gradeLabel"].split("·")[0].strip()

payload["routes"] = {
    "home": f"{web_base_url}/#/",
    "student_detail": f"{web_base_url}/#/students/detail?studentId={primary_student['id']}",
    "class_detail": f"{web_base_url}/#/classes/detail?classId={primary_class['id']}",
    "lesson_detail": f"{web_base_url}/#/lessons/detail?lessonId={primary_lesson['id']}",
    "question_detail": f"{web_base_url}/#/questions/detail?questionId={primary_question['id']}",
    "question_detail_library_context": (
        f"{web_base_url}/#/questions/detail?"
        + urllib.parse.urlencode(
            {
                "questionId": primary_question["id"],
                "initialQuery": primary_class["name"],
                "initialSubjectLabel": primary_class_student["subjectLabel"],
                "initialStageLabel": primary_class_stage,
                "initialTextbookLabel": primary_class["textbookLabel"],
                "flashMessage": f"已定位到 {primary_class['name']} 的题库上下文，可继续按当前班级筛题。",
                "highlightTitle": "当前班级题库上下文",
                "highlightDetail": (
                    f"{primary_class['name']} 的学段、教材和关联学科条件已带入题库，"
                    "可继续筛题、入篮或送入文档。"
                ),
                "feedbackBadgeLabel": "班级筛题",
                "sourceModule": "classes",
                "sourceRecordId": primary_class["id"],
                "sourceLabel": primary_class["name"],
            }
        )
    ),
    "question_detail_student_context": (
        f"{web_base_url}/#/questions/detail?"
        + urllib.parse.urlencode(
            {
                "questionId": primary_question["id"],
                "initialSubjectLabel": primary_student["subjectLabel"],
                "initialStageLabel": primary_student_stage,
                "initialTextbookLabel": primary_student["textbookLabel"],
                "flashMessage": f"已定位到 {primary_student['name']} 的题库上下文，可继续按当前学生筛题。",
                "highlightTitle": "当前学生题库上下文",
                "highlightDetail": (
                    f"{primary_student['name']} 的学科、学段和教材条件已带入题库，"
                    "可继续筛题、入篮或送入文档。"
                ),
                "feedbackBadgeLabel": "学生筛题",
                "sourceModule": "students",
                "sourceRecordId": primary_student["id"],
                "sourceLabel": primary_student["name"],
            }
        )
    ),
    "question_detail_lesson_context": (
        f"{web_base_url}/#/questions/detail?"
        + urllib.parse.urlencode(
            {
                "questionId": primary_question["id"],
                "initialQuery": primary_lesson["title"],
                "initialSubjectLabel": primary_lesson_student["subjectLabel"],
                "initialStageLabel": primary_lesson_stage,
                "initialTextbookLabel": primary_lesson_student["textbookLabel"],
                "flashMessage": f"已定位到 {primary_lesson['title']} 的题库上下文，可继续按当前课堂筛题。",
                "highlightTitle": "当前课堂题库上下文",
                "highlightDetail": (
                    f"{primary_lesson['title']} 的课堂主题和关联学生条件已带入题库，"
                    "可继续筛题、入篮或送入文档。"
                ),
                "feedbackBadgeLabel": "课堂筛题",
                "sourceModule": "lessons",
                "sourceRecordId": primary_lesson["id"],
                "sourceLabel": primary_lesson["title"],
            }
        )
    ),
    "document_detail": (
        f"{web_base_url}/#/documents/detail?documentId={primary_document['id']}"
    ),
    "documents_lesson_context": (
        f"{web_base_url}/#/documents?"
        + urllib.parse.urlencode(
            {
                "focusDocumentId": primary_document["id"],
                "flashMessage": f"已定位到 {primary_document['name']}，可继续整理课堂资料。",
                "highlightTitle": "当前课堂资料",
                "highlightDetail": (
                    f"{primary_document['name']} 正承接当前课堂的资料安排，"
                    "可继续补讲义、试卷和课堂节奏。"
                ),
                "feedbackBadgeLabel": "课堂资料",
                "sourceModule": "lesson_detail",
                "sourceRecordId": primary_lesson["id"],
                "sourceLabel": primary_lesson["title"],
            }
        )
    ),
    "documents_student_context": (
        f"{web_base_url}/#/documents?"
        + urllib.parse.urlencode(
            {
                "focusDocumentId": primary_document["id"],
                "flashMessage": f"已定位到 {primary_document['name']}，可继续整理学生跟进资料。",
                "highlightTitle": "当前学生跟进资料",
                "highlightDetail": (
                    f"{primary_document['name']} 正承接 {primary_student['name']} 的跟进任务，"
                    "可继续补讲义、试卷与课堂反馈。"
                ),
                "feedbackBadgeLabel": "学生跟进",
                "sourceModule": "student_detail",
                "sourceRecordId": primary_student["id"],
                "sourceLabel": primary_student["name"],
            }
        )
    ),
    "documents_class_context": (
        f"{web_base_url}/#/documents?"
        + urllib.parse.urlencode(
            {
                "focusDocumentId": primary_document["id"],
                "flashMessage": f"已定位到 {primary_document['name']}，可继续整理班级资料。",
                "highlightTitle": "当前班级资料",
                "highlightDetail": (
                    f"{primary_document['name']} 正承接 {primary_class['name']} 的资料安排，"
                    "可继续补讲义、试卷和课堂节奏。"
                ),
                "feedbackBadgeLabel": "班级资料",
                "sourceModule": "class_detail",
                "sourceRecordId": primary_class["id"],
                "sourceLabel": primary_class["name"],
            }
        )
    ),
    "documents_home_recent": (
        f"{web_base_url}/#/documents?"
        + urllib.parse.urlencode(
            {
                "focusDocumentId": primary_document["id"],
                "flashMessage": (
                    f"已定位到 {primary_document['name']}，可继续整理最近任务里的文档。"
                ),
                "highlightTitle": "最近任务资料",
                "highlightDetail": (
                    f"{primary_document['name']} 来自首页最近任务，"
                    "可继续整理内容和导出节奏。"
                ),
                "feedbackBadgeLabel": "最近任务",
                "sourceModule": "home",
                "sourceLabel": "工作台",
            }
        )
    ),
    "documents_home_focus": (
        f"{web_base_url}/#/documents?"
        + urllib.parse.urlencode(
            {
                "focusDocumentId": primary_document["id"],
                "flashMessage": (
                    f"已定位到 {primary_document['name']}，可继续整理当前聚焦资料。"
                ),
                "highlightTitle": "当前聚焦资料",
                "highlightDetail": (
                    f"{primary_document['name']} 是当前工作台聚焦的文档，"
                    "可继续回看题目、版式和导出节奏。"
                ),
                "feedbackBadgeLabel": "工作台聚焦",
                "sourceModule": "home",
                "sourceLabel": "工作台",
            }
        )
    ),
    "library_student_context": (
        f"{web_base_url}/#/library?"
        + urllib.parse.urlencode(
            {
                "initialSubjectLabel": primary_student["subjectLabel"],
                "initialStageLabel": primary_student_stage,
                "initialTextbookLabel": primary_student["textbookLabel"],
                "flashMessage": f"已定位到 {primary_student['name']} 的题库上下文，可继续按当前学生筛题。",
                "highlightTitle": "当前学生题库上下文",
                "highlightDetail": (
                    f"{primary_student['name']} 的学科、学段和教材条件已带入题库，"
                    "可继续筛题、入篮或送入文档。"
                ),
                "feedbackBadgeLabel": "学生筛题",
                "sourceModule": "students",
                "sourceRecordId": primary_student["id"],
                "sourceLabel": primary_student["name"],
            }
        )
    ),
    "library_class_context": (
        f"{web_base_url}/#/library?"
        + urllib.parse.urlencode(
            {
                "initialSubjectLabel": primary_class_student["subjectLabel"],
                "initialStageLabel": primary_class_stage,
                "initialTextbookLabel": primary_class["textbookLabel"],
                "flashMessage": f"已定位到 {primary_class['name']} 的题库上下文，可继续按当前班级筛题。",
                "highlightTitle": "当前班级题库上下文",
                "highlightDetail": (
                    f"{primary_class['name']} 的学段、教材和关联学科条件已带入题库，"
                    "可继续筛题、入篮或送入文档。"
                ),
                "feedbackBadgeLabel": "班级筛题",
                "sourceModule": "classes",
                "sourceRecordId": primary_class["id"],
                "sourceLabel": primary_class["name"],
            }
        )
    ),
    "library_lesson_context": (
        f"{web_base_url}/#/library?"
        + urllib.parse.urlencode(
            {
                "initialQuery": primary_lesson["title"],
                "initialSubjectLabel": primary_lesson_student["subjectLabel"],
                "initialStageLabel": primary_lesson_stage,
                "initialTextbookLabel": primary_lesson_student["textbookLabel"],
                "flashMessage": f"已定位到 {primary_lesson['title']} 的题库上下文，可继续按当前课堂筛题。",
                "highlightTitle": "当前课堂题库上下文",
                "highlightDetail": (
                    f"{primary_lesson['title']} 的课堂主题和关联学生条件已带入题库，"
                    "可继续筛题、入篮或送入文档。"
                ),
                "feedbackBadgeLabel": "课堂筛题",
                "sourceModule": "lessons",
                "sourceRecordId": primary_lesson["id"],
                "sourceLabel": primary_lesson["title"],
            }
        )
    ),
}

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False)
PY

capture_via_storage_state() {
  local route_key="$1"
  local output_path="$2"
  echo "capturing route: ${route_key} -> ${output_path}"
  "${proxyless_env[@]}" python3 - "$bridge_payload_file" "$storage_state_file" <<'PY'
import json
import sys

payload_file, output_path = sys.argv[1:]
with open(payload_file, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "auth_session": payload["session"],
            "active_tenant": payload["tenant"],
            "flutter.auth_session": payload["session"],
            "flutter.active_tenant": payload["tenant"],
        },
        handle,
        ensure_ascii=False,
    )
PY

  local route_url
  route_url="$(
    "${proxyless_env[@]}" python3 - "$bridge_payload_file" "$route_key" <<'PY'
import json
import sys

payload_file, route_key = sys.argv[1:]
with open(payload_file, "r", encoding="utf-8") as handle:
    payload = json.load(handle)
print(payload["routes"][route_key])
PY
  )"

  CAPTURE_FULLPAGE_POST_LOAD_DELAY_MS="$capture_post_load_delay_ms" \
  CAPTURE_FULLPAGE_BLANK_RETRIES="$capture_blank_retries" \
  "${proxyless_env[@]}" /Users/honcy/Project/ShiTi/scripts/capture-edge-fullpage.sh \
    "$route_url" \
    "$output_path" \
    "$storage_state_file"
}

echo "Capturing live workspace audit into $output_dir"

capture_via_storage_state \
  "home" \
  "${output_dir}/home-live.png"

capture_via_storage_state \
  "student_detail" \
  "${output_dir}/student-detail-live.png"

capture_via_storage_state \
  "class_detail" \
  "${output_dir}/class-detail-live.png"

capture_via_storage_state \
  "lesson_detail" \
  "${output_dir}/lesson-detail-live.png"

capture_via_storage_state \
  "question_detail" \
  "${output_dir}/question-detail-live.png"

capture_via_storage_state \
  "question_detail_library_context" \
  "${output_dir}/question-detail-library-context-live.png"

capture_via_storage_state \
  "question_detail_student_context" \
  "${output_dir}/question-detail-student-context-live.png"

capture_via_storage_state \
  "question_detail_lesson_context" \
  "${output_dir}/question-detail-lesson-context-live.png"

capture_via_storage_state \
  "document_detail" \
  "${output_dir}/document-detail-live.png"

capture_via_storage_state \
  "documents_lesson_context" \
  "${output_dir}/documents-lesson-context-live.png"

capture_via_storage_state \
  "documents_student_context" \
  "${output_dir}/documents-student-context-live.png"

capture_via_storage_state \
  "documents_class_context" \
  "${output_dir}/documents-class-context-live.png"

capture_via_storage_state \
  "documents_home_recent" \
  "${output_dir}/documents-home-recent-live.png"

capture_via_storage_state \
  "documents_home_focus" \
  "${output_dir}/documents-home-focus-live.png"

capture_via_storage_state \
  "library_student_context" \
  "${output_dir}/library-student-context-live.png"

capture_via_storage_state \
  "library_class_context" \
  "${output_dir}/library-class-context-live.png"

capture_via_storage_state \
  "library_lesson_context" \
  "${output_dir}/library-lesson-context-live.png"

echo "Audit screenshots:"
find "$output_dir" -maxdepth 1 -type f -name '*.png' | sort
