---
layout: post
title: "Experiments in Agentic AI, Part IX: Turning a One-Pass Pipeline into a Claude Code-Style Coding Loop"
date: 2026-04-04
author: Alex Harvey
tags: agentic-ai rag
---

- ToC
{:toc}

## Introduction

Part VIII was my first attempt to build a multi-agent coding pipeline inside my AWS setup while reusing the underlying RAG system. The result was a simple one-pass workflow: Planner → Implementer → Reviewer. I called it “Claude Code” half-jokingly, because it's a multi-agent coding solution using Claude 3.5 Sonnet on Amazon Bedrock.

Then I wondered how far I could get down the path to building a real Claude Code of my own. Part IX takes the next step. Instead of stopping after a single pass, I turn that basic pipeline into a minimal coding loop: generate code, write files, run tests, review the result, feed the failures back in, and iterate.

## Workflow

```
   ┌───────────┐
   │   Plan    │
   └─────┬─────┘
         │
         ▼
   ┌────────────┐    ┌─────────────┐    ┌────────────┐    ┌────────────┐
   │ Implement  │ —▷ │ Write Files │ —▷ │ Run Tests  │ —▷ │   Review   │
   └────────────┘    └─────────────┘    └────────────┘    └─────┬──────┘
         ▲                                                      │
         │                                                      ▼
         │                                              ╱──────────────╲
         │                                             ╱ Major issues   ╲
         │                                            ╱   detected?      ╲
         │                                            ╲                  ╱
         │                                             ╲──────┬───┬─────╱
         │                                                    │   │
         │                                                 Yes│   │No
         │                                                    │   │
         │                                                    │   ▼
         │                                                    │ ┌───────────┐
         │                                                    │ │   Done    │
         │                                                    │ └───────────┘
         │                                                    │
         └────────────────────────────────────────────────────┘
                    fix from test + review feedback
```

## The Code

The full code for Part IX is available here:

https://github.com/alex-harvey-z3q/claude-code-minimal

## Architecture

Before I continue, let me clarify the diagram above. The workflow diagram can give the impression that the LLM is doing all of those steps itself. It is not. In particular, the **Write Files** and **Run Tests** boxes are not happening inside the model or even in Bedrock.

What actually happens is that the LLM proposes code as plain text, then my ECS-hosted Python application writes those files into a workspace directory on the container filesystem, and then runs the tests on them, and then reads the resulting files back from disk, before feeding snapshots of that real workspace into the next prompt.

That means the workspace acts as the loop’s external memory. It is not a special AWS service, just a directory inside the running container that holds the generated code for that workflow run. The LLM only ever sees that workspace indirectly, through whatever file contents the orchestration code chooses to read back into the next prompt.

This distinction matters because it explains why Part IX feels more agentic than Part VIII. The workflow is no longer just passing text from one prompt to the next. It now has a real execution layer underneath it: generated files are written to disk, tests are run against those files, and the results of that execution are fed back into the loop.

## Prompt Design

### Main workflow

The main control flow is in `run_workflow()`:

```python
def run_workflow(
    question: str,
    use_retrieval: bool = True,
) -> dict[str, object]:
    """Execute the full iterative coding workflow."""

    # Retrieval is optional so the same loop can be used both with and without
    # the RAG. That makes it easier to separate "retrieval quality" problems from
    # "agent loop" problems when debugging.
    evidence = retrieve(question) if use_retrieval else []

    # Invoke the Planner and receive its response along with its prompts for
    # debugging.
    plan, plan_trace = plan_task(question, evidence)

    # The workspace is the loop's external memory. Each iteration writes code
    # to disk, runs tests against real files, and then reads those files back
    # for review and for the next retry prompt.
    WORKSPACE_ROOT.mkdir(parents=True, exist_ok=True)

    # These variables track the latest state of the loop. The final response
    # returns the last successful-or-not attempt plus the full per-iteration log.
    code = ""
    review = ""

    issue_summary: str | None = None
    retry_files: list[str] = []
    iterations: list[dict[str, object]] = []

    stop_reason = "max_iterations_reached"

    for iteration in range(1, MAX_ITERS + 1):
        # Iteration 1 is a full generation from the task + evidence + plan.
        # Later iterations switch into patch mode, where the implementer is
        # asked to revise only a targeted subset of files.
        retry_mode = iteration > 1

        # Invoke the Implementer and receive its code along with its prompts
        # for debugging.
        code, implement_trace = implement_task(
            question,
            evidence,
            plan,
            issue_summary=issue_summary,
            retry_mode=retry_mode,
        )

        workspace_snapshot = ""
        blocking_checklist: list[str] = []

        # If we already have reviewer feedback from a previous iteration, build
        # an initial checklist before execution. This makes the current retry's
        # intended targets visible in the trace even before tests run again.
        if issue_summary is not None:
            blocking_checklist = _build_blocking_checklist("", review)

        try:
            # First pass replaces the whole workspace. Retries apply only the
            # emitted files, which is what turns the loop from "regenerate from
            # scratch" into a more Claude Code–style patch-and-retest cycle.
            if retry_mode:
                patch_files_from_response(code, WORKSPACE_ROOT)
            else:
                write_files_from_response(code, WORKSPACE_ROOT)

            # Tests are the authoritative runtime signal. They matter more than
            # the reviewer because they execute the actual code that was written.
            tests_passed, test_output = run_tests(WORKSPACE_ROOT)

            # Read the real workspace back from disk rather than trusting the
            # raw model output. This ensures the reviewer sees exactly what the
            # test runner saw.
            workspace_snapshot = _read_workspace_files(
                WORKSPACE_ROOT,
                sorted(
                    str(path.relative_to(WORKSPACE_ROOT))
                    for path in WORKSPACE_ROOT.rglob("*.py")
                    if path.is_file()
                ),
            )

            # Invoke the Reviewer. The Reviewer is a secondary judge, not the
            # source of truth. Its role is to catch issues that tests missed,
            # while being constrained by explicit runtime facts from the test
            # runner.
            review, review_trace = review_code(
                question,
                evidence,
                workspace_snapshot,
                test_output=test_output,
                tests_passed=tests_passed,
            )

            # Turn test failures and blocking review items into a compact
            # checklist that can be fed into the next retry prompt.
            blocking_checklist = _build_blocking_checklist(test_output, review)

        except ValueError as exc:
            # File-emission problems are treated like blocking failures too.
            # This catches malformed model output such as missing file bodies or
            # broken separators before the test runner even starts.
            tests_passed = False
            test_output = f"File emission validation failed:\n{exc}"
            review = f"MAJOR: {exc}"
            review_trace = {
                "system_prompt": "",
                "user_prompt": "",
                "response": review,
            }
            blocking_checklist = _build_blocking_checklist(test_output, review)

        # The stop decision is deliberately simple: green tests plus no blocking
        # review findings. In practice, a lot of the orchestration work is about
        # making sure "MAJOR" really means "blocking" and not "nice to have".
        has_major_issues = major_issues(review)

        # Capture everything needed to debug the loop after the fact. This is
        # the audit trail: prompts, outputs, runtime results, selected retry
        # files, and the exact checklist used to drive the next iteration.
        iteration_record: dict[str, object] = {
            "iteration": iteration,
            "retry_mode": retry_mode,
            "tests_passed": tests_passed,
            "major_issues": has_major_issues,
            "test_output": test_output,
            "review": review,
            "retry_files": retry_files,
            "issue_summary": issue_summary,
            "blocking_checklist": blocking_checklist,
            "workspace_snapshot": workspace_snapshot,
            "implement_output": code,
            "trace": {
                "implement": implement_trace,
                "review": review_trace,
            },
        }

        iterations.append(iteration_record)

        # Convergence means both judges agree: the tests are green and the
        # reviewer has no grounded blocking objections.
        if tests_passed and not has_major_issues:
            stop_reason = "tests_passed_and_review_clean"
            break

        # If not done, choose a small set of files to revise next time rather
        # than replaying the entire codebase. This is one of the main practical
        # tricks for keeping prompt size under control in an iterative agent.
        retry_files = _select_retry_files(
            _read_workspace_files(
                WORKSPACE_ROOT,
                sorted(
                    str(path.relative_to(WORKSPACE_ROOT))
                    for path in WORKSPACE_ROOT.rglob("*.py")
                    if path.is_file()
                ),
            ),
            test_output,
            review,
            WORKSPACE_ROOT,
        )

        # Build a condensed retry payload from the latest failures and review.
        # This is the feedback channel that turns the workflow into a loop.
        issue_summary = _build_issue_summary(WORKSPACE_ROOT, retry_files, test_output, review)

    # Return the final workspace state, not just the last raw implementer
    # response. That makes the API response match the code that actually ran.
    final_code = _read_workspace_files(
        WORKSPACE_ROOT,
        sorted(
            str(path.relative_to(WORKSPACE_ROOT))
            for path in WORKSPACE_ROOT.rglob("*.py")
            if path.is_file()
        ),
    )

    # Build the actual payload to return to the caller.
    response: dict[str, object] = {
        "evidence": evidence,
        "plan": plan,
        "code": final_code,
        "review": review,
        "iterations": iterations,
        "completed_iteration": len(iterations),
        "stop_reason": stop_reason,
        "trace": {
            "plan": plan_trace,
        },
    }

    return response
```

#### Getting the loop to converge

The hardest part of Part IX was not getting the system to write correct code, but getting it to stop making the same wrong changes in a loop.

At first I assumed iteration itself would do most of the work. If the loop could generate code, run tests, review the result, and retry, then you would think convergence on a working solution would be inevitable. In practice, however, that was not the case. The workflow would often either produce a fully working first draft, and so succeed without iterating at all, or fail a couple of tests and then spend all the remaining iterations wandering sideways rather than repairing the actual defect.

The first problem I encountered was prompt bloat. Initially, I fed the full code, review, and test output back into each iteration. Unfortunately, that made the prompts too large. Once the context filled up, responses started getting truncated, and the loop became even less reliable, leading to a never-ending loop of mistakes caused by truncated responses. So part of getting iteration to work at all was learning that the feedback prompts had to be condensed. A lot of the complexity in the workflow is related to getting the level of detail right in the retry prompts.

I also had to make the loop more observable. So I added the full per-iteration record: prompts, outputs, test results, reviewer comments, selected retry files, and the issue summary being fed back into the next step. That was the point where the real problems became visible.

Still, convergence remained elusive until I learned the next big lesson: the Reviewer should not be allowed to be too creative. Hallucinations in the Reviewer were another major cause of never-ending loops, where the Implementer was sent back hallucinated major issues to fix and was too agreeable to ever push back against them. Even when the code had converged in a practical sense — green tests, correct behaviour, everything running — the Reviewer would sometimes still produce blocking MAJOR comments for things that were not actually part of the requirements. In one run the loop got to 12 passing tests, but the reviewer still complained at MAJOR level about custom board dimensions and mine-count validation, despite also saying the implementation met the core requirements.

That led to the next refinement. I tightened the reviewer prompt so that MAJOR was supposed to mean only one of three things: a failing test, a contradiction of the explicit user request, or a contradiction of mandatory retrieved evidence. But even then, the controller logic lagged behind the prompt. The helper that decides whether blocking issues remain, `major_issues()`, still effectively just scanned for any non-empty MAJOR: line. So even after the reviewer contract improved, the orchestrator could still be derailed by a speculative blocker.

By the end, that was the pattern I kept seeing: convergence was not a single problem. It was a stack of smaller ones. The loop needed to revise the actual failing files, carry forward the real code under test, give the model compact and accurate retry context, and stop the reviewer from inventing reasons to keep going. The surprising part was how much of the work ended up being about control surfaces and observability, not model capability. The model could often fix the code. The harder part was building a loop that knew when it had actually succeeded.

#### Major issues helper

```python
def major_issues(review: str) -> bool:
    """Return True when the review contains any real blocking issues."""
    for raw_line in review.splitlines():
        line = raw_line.strip()
        if not line.startswith("MAJOR:"):
            continue

        remainder = line[len("MAJOR:"):].strip().lower()
        if remainder.startswith("none") or remainder.startswith("no ") or remainder == "n/a":
            continue

        return True

    return False
```

Discussion of some other helper functions is also worthwhile.

The smaller `major_issues()` helper decides whether a review should block the workflow from stopping. In principle, this sounds trivial: just scan the review for a line starting with `MAJOR:`. In practice, however, the LLMs could never be 100% relied upon to obey their contracts and format output in the requested manner. A reviewer that found no blocking issue would often still emit something like `MAJOR: None` or `MAJOR: No major issues found`, even when requested to stay silent in this case. Other times, the Reviewer insisted on using bulleted lists.

#### Retry targeting and issue summary

Note that the first version of this code simply fed the full previous code, full review, and full test output back into the next iteration.

That actually worked fine once or twice, but then the prompts started to bloat and the model began truncating outputs or hallucinating contradictory review claims.

So, the next step was not just to shorten the feedback, but to make it more targeted. Instead of asking the Implementer to reconsider the entire codebase on every retry, the workflow tries to identify a smaller set of files to revise and then builds a condensed retry payload around those files. That is what `_select_retry_files()` and `_build_issue_summary()` are doing together.

Rather than replaying the entire previous iteration, `_build_issue_summary()` builds a smaller retry payload from the selected files, a blocking checklist, condensed test failures, and the extracted review feedback:

```python
def _select_retry_files(code: str, test_output: str, review: str, workspace: Path) -> list[str]:
    """Choose a small set of files to rewrite on retry iterations.

    Selection should be based on the actual workspace, not only on the most recent
    implementer response, because retries often emit only a subset of files.
    """
    if workspace.exists():
        available = {
            str(path.relative_to(workspace))
            for path in workspace.rglob("*")
            if path.is_file() and path.suffix in {".py", ".txt", ".md", ".json", ".yaml", ".yml"}
        }
    else:
        available = {filename for filename, _ in _parse_files_from_response(code)}

    selected: list[str] = []

    for text in (test_output, review):
        for match in _PATH_RE.finditer(text):
            path = match.group("path")
            if path in available and path not in selected:
                selected.append(path)

    for path in list(selected):
        if Path(path).name.startswith("test_") or "tests" in Path(path).parts:
            for related in _infer_related_source_file(path, workspace):
                if related in available and related not in selected:
                    selected.append(related)

    if not selected and workspace.exists():
        py_files = sorted(
            str(path.relative_to(workspace))
            for path in workspace.rglob("*.py")
            if path.is_file()
        )
        preferred = [name for name in py_files if Path(name).name.startswith("test_") or "tests" in Path(name).parts]
        non_tests = [name for name in py_files if name not in preferred]
        selected = preferred[:3] + non_tests[:3]

    return selected[:6]


def _build_blocking_checklist(test_output: str, review: str) -> list[str]:
    """Turn concrete test failures and MAJOR review items into a blocking checklist."""
    checklist: list[str] = []

    for line in test_output.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith(("FAIL:", "ERROR:")):
            checklist.append(stripped)

    major_lines, _ = _extract_review_items(review)
    checklist.extend(major_lines)

    deduped: list[str] = []
    seen: set[str] = set()
    for item in checklist:
        if item not in seen:
            deduped.append(item)
            seen.add(item)

    return deduped


def _build_issue_summary(
    workspace: Path,
    retry_files: list[str],
    test_output: str,
    review: str,
) -> str:
    """Build the retry payload for the next implementation attempt."""

    parts = ["Files to revise:\n" + "\n".join(f"- {name}" for name in retry_files)]

    blocking_checklist = _build_blocking_checklist(test_output, review)

    if blocking_checklist:
        parts.append(
            "Blocking checklist for this iteration:\n"
            + "\n".join(f"{i}. {item}" for i, item in enumerate(blocking_checklist, start=1))
            + "\n\nClear every item in this checklist before making any optional improvements."
        )

    file_block = _read_workspace_files(workspace, retry_files)

    if file_block:
        parts.append(f"Current file contents:\n{file_block}")

    if test_output.strip():
        parts.append(f"Test failures:\n{_summarize_test_output(test_output)}")

    major_lines, minor_lines = _extract_review_items(review)

    if major_lines:
        parts.append("Blocking review feedback:\n" + "\n".join(major_lines))
    if minor_lines:
        parts.append("Non-blocking review feedback:\n" + "\n".join(minor_lines))

    return "\n\n".join(parts).strip()
```

#### Reviewer

The `review_code()` function is where the Reviewer role is defined. Its job is to look at the code that was actually written to the workspace, compare that against the task and the retrieved evidence, and decide whether there are still any blocking issues.

What made the Reviewer tricky was that it had to be useful without becoming destructive. A reviewer that is too weak is pointless, because it adds nothing beyond the test runner. But a reviewer that is too imaginative is worse: it can keep the loop alive indefinitely by inventing new “major” issues that are not really part of the task. A lot of the convergence work in Part IX ended up being about constraining this agent so that it behaved more like a careful code reviewer and less like a brainstorming partner.

That is why the prompt in `review_code()` became so specific. The Reviewer is told to treat the runtime test results as authoritative, not to guess whether tests ran, and to reserve MAJOR only for three cases: a failing test, a contradiction of the explicit user request, or a contradiction of mandatory retrieved evidence. Everything else is supposed to be pushed down to `MINOR`. In other words, the role of the Reviewer is not to suggest every possible improvement. Its role is to answer a narrower orchestration question: is there still a grounded reason this workflow should keep iterating?

That made `review_code()` one of the most important pieces of the whole system. The quality of the loop depended not just on whether the Reviewer could find problems, but on whether it could find the right kind of problems in a format the controller could safely act on.

```python
def review_code(
    question: str,
    evidence: list[dict],
    code: str,
    *,
    test_output: str = "",
    tests_passed: bool = False,
) -> tuple[str, dict[str, str]]:
    """Ask the reviewer model for tightly constrained blocking vs non-blocking feedback.

    The reviewer is grounded with explicit runtime test facts so it does not
    invent contradictory claims about whether tests ran or passed.
    """
    system_prompt = (
        "You are Reviewer, a strict software review agent. Review generated Python code for "
        "correctness, completeness, and adherence to retrieved evidence. Be conservative. "
        "Do not invent requirements. Do not speculate. Do not suggest optional features as blockers. "
        "When retrieved evidence contains implementation conventions, style guidance, file "
        "layout guidance, testing guidance, naming guidance, or CLI conventions, treat those "
        "conventions as the review baseline only when they are clearly mandatory and do not "
        "conflict with the user's explicit requirements."
    )
    user_prompt = (
        f"Task: {question}\n\n"
        f"Retrieved evidence:\n{_format_evidence(evidence)}\n\n"
        "This workflow uses unittest only.\n"
        "Do not recommend pytest, pytest.ini, setup.cfg, or third-party test runners.\n"
        "Do not infer or guess test execution facts. Use the authoritative runtime test facts below as ground truth.\n\n"
        "Strict MAJOR rules:\n"
        "- Only mark something as MAJOR if it is a blocking defect caused by one of:\n"
        "  1. a failing test,\n"
        "  2. a direct contradiction of the explicit user request, or\n"
        "  3. a direct contradiction of mandatory retrieved evidence.\n"
        "- If tests pass, assume the implementation is acceptable unless you can point to a specific unmet explicit requirement or mandatory evidence requirement.\n"
        "- Do not invent requirements.\n"
        "- Do not treat robustness improvements, common extensions, custom board sizes, extra validation, timers, question marks, chording, or other nice-to-haves as MAJOR unless they were explicitly required.\n"
        "- Missing optional features, polish, extra safeguards, or common features must be MINOR, not MAJOR.\n"
        "- Do not mark something MAJOR just because it 'could' be improved or is 'commonly' present.\n\n"
        f"{_build_test_status(test_output, tests_passed)}\n\n"
        "Review the generated implementation. Focus on:\n"
        "- correctness\n"
        "- adherence to explicit task requirements\n"
        "- contradictions with mandatory retrieved evidence\n"
        "- edge cases that actually violate the task\n"
        "- structure and readability\n"
        "- test coverage for required behaviour\n\n"
        "Return short bullet points only. Prefix each bullet with one of:\n"
        "- PASS:\n"
        "- MINOR:\n"
        "- MAJOR:\n\n"
        "For every MAJOR item, start the text with one of these labels:\n"
        "- MAJOR: FAILING_TEST - ...\n"
        "- MAJOR: USER_REQUIREMENT - ...\n"
        "- MAJOR: MANDATORY_EVIDENCE - ...\n\n"
        "If you cannot justify a MAJOR item with one of those three labels, it must be MINOR instead.\n\n"
        f"Raw test output:\n{test_output or 'No test output.'}\n\n"
        f"Code:\n{code}"
    )
    response = invoke_claude(system_prompt, user_prompt, max_tokens=1000, temperature=0.0)
    return response, {
        "system_prompt": system_prompt,
        "user_prompt": user_prompt,
        "response": response,
    }
```

## The human reviewer

That's me. Having finally made a workflow that would generally converge on a solution in a couple of iterations, I decided to review the quality of the implementations for myself.

| Run | Completed iteration | Stop reason                    | Interpretation                        |
|-----|---------------------|--------------------------------|---------------------------------------|
| 1   | 3                   | `tests_passed_and_review_clean` | Needed retries, then converged        |
| 2   | 1                   | `tests_passed_and_review_clean` | Solved immediately                    |
| 3   | 3                   | `tests_passed_and_review_clean` | Needed retries, then converged        |
| 4   | 10                  | `max_iterations_reached`        | Still stalled despite full budget     |
| 5   | 5                   | `tests_passed_and_review_clean` | Slower convergence, but still solved  |

Overall, 4 out of 5 runs converged cleanly, while 1 run exhausted the iteration budget without reaching a clean stop condition.

### Manual validation

The workflow’s own signals are only part of the picture. A run can stop with `tests_passed_and_review_clean`, but that still does not guarantee that the final artifact feels right in practice.

So I also ran the generated Minesweeper games manually and played them myself. That was a useful reminder that passing the loop’s stopping criteria is not the same thing as producing polished software. The final version was playable and broadly correct, but manual use is still the best way to notice rough edges in the interface, awkward controls, or behaviours that the tests did not capture.

### Run 1

Not off to a great start since I wasn't able to run the application without tweaking some files. After fixing it up so that its CLI could be run, I then got a Minesweeper board:

```
Select difficulty:
1. Beginner (9x9, 10 mines)
2. Intermediate (16x16, 40 mines)
3. Expert (30x16, 99 mines)
Enter choice (1-3): 1
```

```
Mines remaining: 10
Time: 0 seconds
   0 1 2 3 4 5 6 7 8
  +-----------------+
 0| 0 0 0 1           |
 1| 0 0 0 2           |
 2| 0 0 0 2           |
 3| 1 1 0 1           |
 4|   2 1 1           |
 5|                   |
 6|                   |
 7|                   |
 8|                   |
  +-----------------+
Commands: x y = reveal, x y f = flag, q = quit
Enter move (x y [f for flag]):
```

Notice the ASCII borders don't quite line up. That seems to be a common LLM problem.

Also sadly I notice that the game is revealing the board's underlying state instead of showing unopened cells as something like ., #, or □.

So I have had to mark this first iteration as a failure.

### Run 2

The second run looks better. Its tests really passed, its CLI was working, and it displayed the board correctly:

```
Select difficulty:
1. Beginner (9x9, 10 mines)
2. Intermediate (16x16, 40 mines)
3. Expert (30x16, 99 mines)
Enter choice (1-3): 1
```

```
    0 1 2 3 4 5 6 7 8
   ------------------
 0|□□□□□□□□□
 1|□□□□□□□□□
 2|□□□□□□□□□
 3|□□□□□□□□□
 4|□□□□□□□□□
 5|□□□□□□□□□
 6|□□□□□□□□□
 7|□□□□□□□□□
 8|□□□□□□□□□

Mines remaining: 10

Enter move (row col [f for flag]): 
```

Now I'm marking this version of the game down for providing no instructions on how to play. I had to guess that to reveal 1, 1 I would type `1 1`.

```
    0 1 2 3 4 5 6 7 8
   ------------------
 0|       11
 1|       1💣
 2|       11
 3|111111
 4|□💣□□💣1
 5|□□💣💣□2
 6|□□□□💣1 11
 7|□💣□□□212💣
 8|💣□□□□□💥□□

Mines remaining: 9

Game Over! Time played: 295 seconds

Play again? (y/n):
```

### Run 3

The third run was another disappointment. All 10 unit tests passed, but the game still crashed immediately on startup when I tried to play it manually. The CLI attempted to return `Game.BEGINNER`, but the `Game` class had no such attribute. That was a useful reminder that passing the generated test suite and producing a genuinely usable artifact are not the same thing.

### Run 4

Run 4 is the one that had failed to converge. The story of why it failed to converge is somewhat amusing actually. The tests defined `Board.reveal()` as a success/failure API: safe reveal should return `True`, mine reveal should return `False`. But the implementation defined it the other way: `Board.reveal()` means “did this hit a mine?” API instead. In `board.py`, revealing a mine returns `True`, and in `game.py` that return value is assigned to hit_mine and used exactly that way: `if hit_mine: self.game_over = True`.

Between the Reviewer and Implementer however, they weren't able to sort this one out! However, the game in run 4 did actually work fine.

```
Mines remaining: 8
Time: 32s

   012345678
 0 ...1    F
 1 ...1   1
 2 1111    F
 3    *
 4     2
 5      2
 6
 7
 8
Game Over!
Time: 32s
```

### Run 5

Run 5 is the run that finally produced a nice-looking user experience and ASCII game board design!

```
Select difficulty:
1. Beginner (9x9, 10 mines)
2. Intermediate (16x16, 40 mines)
3. Expert (30x16, 99 mines)
4. Custom
Enter choice (1-4): 1
```

```
Mines remaining: 10
Time: 0 seconds
   0 1 2 3 4 5 6 7 8
  -------------------
 0| ■ ■ ■ ■ ■ ■ ■ ■ ■
 1| ■ ■ ■ ■ ■ ■ ■ ■ ■
 2| ■ ■ ■ ■ ■ ■ ■ ■ ■
 3| ■ ■ ■ ■ ■ ■ ■ ■ ■
 4| ■ ■ ■ ■ ■ ■ ■ ■ ■
 5| ■ ■ ■ ■ ■ ■ ■ ■ ■
 6| ■ ■ ■ ■ ■ ■ ■ ■ ■
 7| ■ ■ ■ ■ ■ ■ ■ ■ ■
 8| ■ ■ ■ ■ ■ ■ ■ ■ ■

Enter action (r x y for reveal, f x y for flag, q to quit): r 2 2

Mines remaining: 10
Time: 0 seconds
   0 1 2 3 4 5 6 7 8
  -------------------
 0|           1 ■ ■ ■
 1|         1 2 ■ ■ ■
 2|         1 ■ ■ ■ ■
 3| 1 1 1   1 1 2 ■ ■
 4| ■ ■ 1       1 ■ ■
 5| ■ ■ 1       1 ■ ■
 6| ■ ■ 1 1 1 2 2 ■ ■
 7| ■ ■ ■ ■ ■ ■ ■ ■ ■
 8| ■ ■ ■ ■ ■ ■  ■ ■

Enter action (r x y for reveal, f x y for flag, q to quit):
```

There was only one minor problem with this implementation, a warning caused by unnecessary import of the CLI in `__init__.py`. 

## Conclusion

So, Part IX has got this workflow over an important threshold. It is no longer just a one-pass prompt pipeline that happens to involve multiple agents. It can now generate code, write files into a real workspace, runs tests against that code, reviews the result, and retries with targeted feedback.

That still does not make it a robust coding agent. The manual testing results from the five runs made that clear. Four out of five runs converged according to the workflow’s own stop condition, but manual testing showed that convergence and quality are not the same thing. One version revealed the hidden board state, another crashed on startup despite passing its tests, and only the final run really felt like a usable Minesweeper game.

That is probably the main lesson from Part IX. Once iteration is introduced, the hard part is no longer just code generation. The hard part is orchestration: deciding what feedback to carry forward, what to ignore, which files to revise, and when to stop. In other words, the problem shifts from prompting a model once to building a controller around it.

So I can't quite boast yet that “I built Claude Code.” But I did something more modest, and still useful: I now have a minimal coding loop that can genuinely improve its own outputs, and I have a much clearer picture of what still separates that from a reliable coding agent.

## What comes next

The next step is to make the loop less dependent on fragile prompt reconstruction and more like a real coding agent. Right now, the LLM only sees the workspace indirectly through file contents that my orchestration code reads back into prompts. That works, but it is inefficient and brittle. A more serious version of this system would need tighter integration with the workspace itself, so that iteration is happening over real files and commands rather than repeatedly serialising everything back into text.

I also need to improve validation. Part IX showed that generated tests and reviewer approval are not enough. A workflow can stop cleanly and still produce a poor user experience or even a broken application. So the next round of work needs stronger runtime checks, better end-to-end tests, and probably a stricter separation between “the code passed its own tests” and “the artifact is actually good.”

Finally, there is still a lot of prompt and control logic to simplify. The Reviewer became too creative, boolean contracts turned out to be surprisingly ambiguous, and small helpers like `major_issues()` ended up having more influence over convergence than I expected. So Part X will probably be less about adding more agents, and more about making this loop more trustworthy, less wasteful, and closer to a real Claude Code–style system.
