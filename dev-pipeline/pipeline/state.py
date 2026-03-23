"""파이프라인 실행 상태 관리 모듈."""

from __future__ import annotations

import json
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

# 파이프라인 스테이지 순서 (full 템플릿 기준)
STAGE_ORDER = [
    "initialized",
    "architecting",   # 기획 에이전트 (새 Stage -1)
    "git_analyzing",  # Git pre-analyzer (새 Stage 0)
    "planning",       # Planner
    "coding",         # Coder
    "testing",        # Tester
    "reviewing",      # Reviewer
    "completed",
]

# 파이프라인 템플릿 정의
PIPELINE_TEMPLATES: dict[str, list[str]] = {
    # 기본값: Architect 없이 바로 Git분석 → 계획 → 구현 → 검증
    "standard": ["git_analyzing", "planning", "coding", "testing", "reviewing"],
    # Architect 포함: 새 기능 설계, 신규 프로젝트, 큰 기능 추가 시
    "plan": ["architecting", "git_analyzing", "planning", "coding", "testing", "reviewing"],
    # 빠른 버그 수정
    "hotfix": ["coding", "testing"],
    # 리팩토링 전용 (Tester 없이 Reviewer 중심)
    "refactor": ["git_analyzing", "planning", "coding", "reviewing"],
    # 레거시 호환 (기존 full → plan으로 마이그레이션 안내용)
    "full": ["architecting", "git_analyzing", "planning", "coding", "testing", "reviewing"],
}


def _runs_dir() -> Path:
    return Path(".pipeline/runs")


def _run_dir(run_id: str) -> Path:
    return _runs_dir() / run_id


def _state_file(run_id: str) -> Path:
    return _run_dir(run_id) / "state.json"


def _save_state(state: dict[str, Any]) -> None:
    path = _state_file(state["run_id"])
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)


def init_run(requirements: str, template: str = "standard") -> str:
    """새 파이프라인 실행을 초기화하고 run_id를 반환합니다."""
    run_id = datetime.now().strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:6]
    stages = PIPELINE_TEMPLATES.get(template, PIPELINE_TEMPLATES["full"])

    state: dict[str, Any] = {
        "run_id": run_id,
        "requirements": requirements,
        "template": template,
        "stages": stages,
        "status": "initialized",
        "current_stage_index": -1,
        "iteration": 0,
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat(),
        "stage_history": [],
    }
    _save_state(state)

    # 실행 디렉토리 내 artifacts 디렉토리 생성
    (_run_dir(run_id) / "artifacts").mkdir(parents=True, exist_ok=True)

    return run_id


def load_state(run_id: str) -> dict[str, Any]:
    """저장된 상태를 로드합니다."""
    path = _state_file(run_id)
    if not path.exists():
        raise FileNotFoundError(f"Run '{run_id}' not found at {path}")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def advance_stage(run_id: str, completed_stage: str) -> dict[str, Any]:
    """완료된 스테이지를 기록하고 다음 스테이지로 전진합니다."""
    state = load_state(run_id)
    stages: list[str] = state["stages"]

    # 완료 스테이지 기록
    state["stage_history"].append({
        "stage": completed_stage,
        "completed_at": datetime.now().isoformat(),
    })

    # 다음 스테이지 인덱스 계산
    current_idx = state["current_stage_index"]
    next_idx = current_idx + 1

    if next_idx >= len(stages):
        state["status"] = "completed"
    else:
        state["status"] = stages[next_idx]
        state["current_stage_index"] = next_idx

    # coding 스테이지를 재실행하는 경우 iteration 증가
    if completed_stage == "testing" and state["status"] == "coding":
        state["iteration"] = state.get("iteration", 0) + 1

    state["updated_at"] = datetime.now().isoformat()
    _save_state(state)
    return state


def increment_iteration(run_id: str) -> dict[str, Any]:
    """피드백 루프 재실행 시 iteration을 증가시킵니다."""
    state = load_state(run_id)
    state["iteration"] = state.get("iteration", 0) + 1
    state["updated_at"] = datetime.now().isoformat()
    _save_state(state)
    return state


def mark_complete(run_id: str) -> dict[str, Any]:
    """파이프라인을 완료 처리합니다."""
    state = load_state(run_id)
    state["status"] = "completed"
    state["completed_at"] = datetime.now().isoformat()
    state["updated_at"] = datetime.now().isoformat()
    _save_state(state)
    return state


def mark_failed(run_id: str, reason: str) -> dict[str, Any]:
    """파이프라인을 실패 처리합니다."""
    state = load_state(run_id)
    state["status"] = "failed"
    state["failure_reason"] = reason
    state["failed_at"] = datetime.now().isoformat()
    state["updated_at"] = datetime.now().isoformat()
    _save_state(state)
    return state


def list_runs() -> list[dict[str, Any]]:
    """모든 파이프라인 실행 목록을 반환합니다."""
    runs_dir = _runs_dir()
    if not runs_dir.exists():
        return []

    runs = []
    for run_dir in sorted(runs_dir.iterdir(), reverse=True):
        state_file = run_dir / "state.json"
        if state_file.exists():
            with open(state_file, encoding="utf-8") as f:
                runs.append(json.load(f))
    return runs
