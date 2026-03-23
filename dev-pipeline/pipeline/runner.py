"""파이프라인 CLI 실행기 — Claude Code 스킬에서 호출됩니다."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def _ensure_pipeline_dir() -> None:
    Path(".pipeline/runs").mkdir(parents=True, exist_ok=True)


def _bootstrap() -> None:
    """dev-pipeline 패키지를 sys.path에 추가합니다."""
    sys.path.insert(0, str(Path(__file__).parent.parent))


def cmd_init(requirements: str, template: str = "standard") -> None:
    """`init` 명령: 새 파이프라인 실행을 초기화합니다."""
    _ensure_pipeline_dir()
    _bootstrap()
    from pipeline.state import init_run

    run_id = init_run(requirements, template=template)
    print(run_id)


def cmd_advance(run_id: str, completed_stage: str) -> None:
    """`advance` 명령: 파이프라인 단계를 전진시킵니다."""
    _bootstrap()
    from pipeline.state import advance_stage

    state = advance_stage(run_id, completed_stage)
    print(f"Status: {state['status']} | Iteration: {state.get('iteration', 0)}")


def cmd_complete(run_id: str) -> None:
    """`complete` 명령: 파이프라인을 완료 처리합니다."""
    _bootstrap()
    from pipeline.state import mark_complete

    mark_complete(run_id)
    print(f"Pipeline {run_id} marked as COMPLETE")


def cmd_fail(run_id: str) -> None:
    """`fail` 명령: 파이프라인을 실패 처리합니다."""
    _bootstrap()
    from pipeline.state import mark_failed

    mark_failed(run_id, "최대 반복 횟수 초과")
    print(f"Pipeline {run_id} marked as FAILED")


def cmd_status(run_id: str) -> None:
    """`status` 명령: 현재 파이프라인 상태를 출력합니다."""
    _bootstrap()
    from pipeline.state import load_state

    state = load_state(run_id)
    print(json.dumps(state, indent=2, ensure_ascii=False))


def cmd_list() -> None:
    """`list` 명령: 모든 파이프라인 실행 목록을 출력합니다."""
    _bootstrap()
    from pipeline.state import list_runs

    runs = list_runs()
    if not runs:
        print("실행된 파이프라인이 없습니다.")
        return

    print(f"{'Run ID':<28} {'Status':<14} {'Template':<10} {'Iter':<6} {'Requirements'}")
    print("-" * 90)
    for run in runs:
        req = run.get("requirements", "")[:40]
        print(
            f"{run['run_id']:<28} {run['status']:<14} "
            f"{run.get('template', 'full'):<10} {run.get('iteration', 0):<6} {req}"
        )


def cmd_record_failure(run_id: str) -> None:
    """`record-failure` 명령: 현재 실행의 실패 패턴을 기록합니다."""
    _bootstrap()
    from pipeline.state import load_state
    from pipeline.failure_memory import record_failure

    state = load_state(run_id)
    run_dir = Path(f".pipeline/runs/{run_id}")

    # test_result.json에서 실패 정보 추출
    test_result_path = run_dir / "test_result.json"
    if not test_result_path.exists():
        print(f"test_result.json not found for run {run_id}")
        return

    with open(test_result_path, encoding="utf-8") as f:
        test_result = json.load(f)

    if test_result.get("status") != "fail":
        print("No failure to record (status is not 'fail')")
        return

    # code_result.json에서 변경 파일 추출
    affected_files: list[str] = []
    code_result_path = run_dir / "code_result.json"
    if code_result_path.exists():
        with open(code_result_path, encoding="utf-8") as f:
            code_result = json.load(f)
        affected_files = [f["path"] for f in code_result.get("files_modified", [])]

    feedback = test_result.get("feedback", "")
    qa = test_result.get("qa_results", {})
    failed_details = qa.get("failed_details", [])

    record_failure(
        run_id=run_id,
        stage="testing",
        error_type="test_failure",
        description=feedback[:200] if feedback else "테스트 실패",
        affected_files=affected_files,
        root_cause=str(failed_details[:2]) if failed_details else feedback[:100],
        fix_applied="",
        tags=[state.get("template", "full")],
    )
    print(f"Failure pattern recorded for run {run_id}")


def cmd_patterns() -> None:
    """`patterns` 명령: 저장된 실패 패턴 목록을 출력합니다."""
    _bootstrap()
    from pipeline.failure_memory import load_patterns

    patterns = load_patterns()
    if not patterns:
        print("저장된 실패 패턴이 없습니다.")
        return

    print(f"총 {len(patterns)}개 패턴:\n")
    for p in patterns:
        print(f"[{p['id']}] {p['error_type']} — {p['description'][:60]}")
        print(f"  발생: {p.get('occurrence_count', 1)}회 | 스테이지: {p['stage']}")
        print(f"  파일: {', '.join(p.get('affected_files', [])[:3])}")
        if p.get("known_fixes"):
            print(f"  수정방법: {p['known_fixes'][0][:80]}")
        print()


def cmd_run(requirements: str) -> None:
    """`run` 명령: Python 오케스트레이터로 전체 파이프라인을 실행합니다."""
    _bootstrap()
    from pipeline.orchestrator import main  # type: ignore[import]

    main(requirements)


def main_cli() -> None:
    """CLI 진입점."""
    if len(sys.argv) < 2:
        print(
            "Usage:\n"
            "  python pipeline/runner.py init <requirements> [--template full|hotfix|refactor]\n"
            "  python pipeline/runner.py advance <run_id> <stage>\n"
            "  python pipeline/runner.py complete <run_id>\n"
            "  python pipeline/runner.py fail <run_id>\n"
            "  python pipeline/runner.py status <run_id>\n"
            "  python pipeline/runner.py list\n"
            "  python pipeline/runner.py record-failure <run_id>\n"
            "  python pipeline/runner.py patterns\n"
            "  python pipeline/runner.py run <requirements>"
        )
        sys.exit(1)

    command = sys.argv[1]

    if command == "init":
        if len(sys.argv) < 3:
            print("Error: requirements 인자가 필요합니다.")
            sys.exit(1)
        # --template 플래그 파싱
        template = "standard"
        args = sys.argv[2:]
        if "--template" in args:
            idx = args.index("--template")
            if idx + 1 < len(args):
                template = args[idx + 1]
                args = args[:idx] + args[idx + 2:]
        cmd_init(" ".join(args), template=template)

    elif command == "advance":
        if len(sys.argv) < 4:
            print("Error: run_id와 stage 인자가 필요합니다.")
            sys.exit(1)
        cmd_advance(sys.argv[2], sys.argv[3])

    elif command == "complete":
        if len(sys.argv) < 3:
            print("Error: run_id 인자가 필요합니다.")
            sys.exit(1)
        cmd_complete(sys.argv[2])

    elif command == "fail":
        if len(sys.argv) < 3:
            print("Error: run_id 인자가 필요합니다.")
            sys.exit(1)
        cmd_fail(sys.argv[2])

    elif command == "status":
        if len(sys.argv) < 3:
            print("Error: run_id 인자가 필요합니다.")
            sys.exit(1)
        cmd_status(sys.argv[2])

    elif command == "list":
        cmd_list()

    elif command == "record-failure":
        if len(sys.argv) < 3:
            print("Error: run_id 인자가 필요합니다.")
            sys.exit(1)
        cmd_record_failure(sys.argv[2])

    elif command == "patterns":
        cmd_patterns()

    elif command == "run":
        if len(sys.argv) < 3:
            print("Error: requirements 인자가 필요합니다.")
            sys.exit(1)
        cmd_run(" ".join(sys.argv[2:]))

    else:
        print(f"Error: 알 수 없는 명령어 '{command}'")
        sys.exit(1)


if __name__ == "__main__":
    main_cli()
