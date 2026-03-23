"""실패 학습 메모리 모듈 — 반복 실패 패턴을 누적·조회합니다."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any

# 실패 패턴 저장 경로 (전역 — 프로젝트 무관하게 누적)
FAILURE_PATTERNS_PATH = Path("D:/.claude/dev-pipeline/failure-patterns.json")


def _load_raw() -> dict[str, Any]:
    """failure-patterns.json을 로드합니다. 없으면 빈 구조 반환."""
    if FAILURE_PATTERNS_PATH.exists():
        with open(FAILURE_PATTERNS_PATH, encoding="utf-8") as f:
            return json.load(f)
    return {"patterns": [], "updated_at": None}


def _save_raw(data: dict[str, Any]) -> None:
    FAILURE_PATTERNS_PATH.parent.mkdir(parents=True, exist_ok=True)
    data["updated_at"] = datetime.now().isoformat()
    with open(FAILURE_PATTERNS_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def record_failure(
    run_id: str,
    stage: str,
    error_type: str,
    description: str,
    affected_files: list[str],
    root_cause: str,
    fix_applied: str,
    tags: list[str] | None = None,
) -> None:
    """실패 패턴을 기록합니다.

    Args:
        run_id: 파이프라인 실행 ID
        stage: 실패 발생 스테이지 (coding, testing 등)
        error_type: 오류 유형 (syntax_error, test_failure, import_error 등)
        description: 실패 상황 설명
        affected_files: 영향받은 파일 목록
        root_cause: 근본 원인
        fix_applied: 적용된 수정 방법
        tags: 검색용 태그 (예: ["python", "import", "circular"])
    """
    data = _load_raw()

    # 동일 패턴 중복 체크 (description + error_type 기준)
    for pattern in data["patterns"]:
        if pattern["error_type"] == error_type and pattern["root_cause"] == root_cause:
            # 기존 패턴 업데이트 (발생 횟수 증가)
            pattern["occurrence_count"] = pattern.get("occurrence_count", 1) + 1
            pattern["last_seen"] = datetime.now().isoformat()
            pattern["run_ids"].append(run_id)
            if fix_applied and fix_applied not in pattern.get("known_fixes", []):
                pattern.setdefault("known_fixes", []).append(fix_applied)
            _save_raw(data)
            return

    # 새 패턴 추가
    pattern: dict[str, Any] = {
        "id": f"FP{len(data['patterns']) + 1:04d}",
        "error_type": error_type,
        "stage": stage,
        "description": description,
        "affected_files": affected_files,
        "root_cause": root_cause,
        "known_fixes": [fix_applied] if fix_applied else [],
        "avoidance_guide": f"{root_cause}를 피하려면: {fix_applied}",
        "occurrence_count": 1,
        "first_seen": datetime.now().isoformat(),
        "last_seen": datetime.now().isoformat(),
        "run_ids": [run_id],
        "tags": tags or [],
    }
    data["patterns"].append(pattern)
    _save_raw(data)


def load_patterns() -> list[dict[str, Any]]:
    """저장된 모든 실패 패턴을 반환합니다."""
    return _load_raw().get("patterns", [])


def get_relevant_patterns(
    files: list[str],
    error_types: list[str] | None = None,
    tags: list[str] | None = None,
    limit: int = 10,
) -> list[dict[str, Any]]:
    """현재 작업과 관련된 실패 패턴을 조회합니다.

    Args:
        files: 현재 작업 중인 파일 목록
        error_types: 필터링할 오류 유형 (None이면 전체)
        tags: 필터링할 태그 (None이면 전체)
        limit: 최대 반환 개수

    Returns:
        관련성 높은 실패 패턴 목록 (발생 횟수 내림차순)
    """
    all_patterns = load_patterns()
    relevant: list[dict[str, Any]] = []

    for pattern in all_patterns:
        score = 0

        # 파일 매칭
        pattern_files = set(pattern.get("affected_files", []))
        file_overlap = pattern_files & set(files)
        score += len(file_overlap) * 3

        # 오류 유형 매칭
        if error_types and pattern["error_type"] in error_types:
            score += 2

        # 태그 매칭
        if tags:
            tag_overlap = set(pattern.get("tags", [])) & set(tags)
            score += len(tag_overlap)

        if score > 0:
            relevant.append({**pattern, "_relevance_score": score})

    # 관련성 → 발생 횟수 순 정렬
    relevant.sort(key=lambda x: (-x["_relevance_score"], -x.get("occurrence_count", 1)))
    return relevant[:limit]


def format_patterns_for_coder(patterns: list[dict[str, Any]]) -> str:
    """Coder 에이전트에게 전달할 과거 실패 패턴 요약 텍스트를 생성합니다."""
    if not patterns:
        return "이전 실패 패턴 없음."

    lines = ["## ⚠️ 과거 실패 패턴 — 사전 회피 가이드\n"]
    for i, p in enumerate(patterns, 1):
        lines.append(f"### {i}. [{p['error_type']}] {p['description']}")
        lines.append(f"- **발생 횟수:** {p.get('occurrence_count', 1)}회")
        lines.append(f"- **근본 원인:** {p['root_cause']}")
        if p.get("known_fixes"):
            lines.append(f"- **검증된 수정 방법:** {p['known_fixes'][0]}")
        lines.append(f"- **관련 파일:** {', '.join(p.get('affected_files', []))}")
        lines.append("")
    return "\n".join(lines)
