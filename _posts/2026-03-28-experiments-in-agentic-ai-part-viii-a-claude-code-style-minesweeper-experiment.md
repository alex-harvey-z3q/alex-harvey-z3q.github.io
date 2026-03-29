---
layout: post
title: "Experiments in Agentic AI, Part VIII: A Claude Code-Style Minesweeper Experiment"
date: 2026-03-28
author: Alex Harvey
tags: rag agentic-ai
---

- ToC
{:toc}

## Introduction

In the last post I switched from OpenAI over to Amazon Bedrock running Claude. With that in place, I decided to push things a bit further and see if it could handle something more ambitious: generating a complete application via a simple multi-agent workflow.

To explore that, I needed a task that was simple enough to be tractable, but well understood enough to make differences in output easy to spot. I picked the classic problem of building a terminal-based Minesweeper game in Python. This serves as a controlled test case — the goal is not the game itself, but to understand when retrieval actually changes model behavior.

---

## Architecture

For a full discussion of the architecture, see Parts V and VII. The main change in this post is adding multiple agents to the workflow.

At a high level, the system now looks like this:

```
   +------------------+           +----------------------+
   | Wikipedia pages  |           | Internal style guide |
   +---------+--------+           +----------+-----------+
             |                               |
             +---------------+---------------+
                             |
                             ▼
                    +------------------+
                    |      Ingest      |
                    | parse/normalise  |
                    +--------+---------+
                             |
                             ▼
                    +------------------+
                    |      Indexer     |
                    | chunk / embed    |
                    +--------+---------+
                             |
                             ▼
                    +------------------+
                    |    pgvector DB   |
                    +--------+---------+
                             |
                             ▼
                    +------------------+
                    |     Retrieval    |
                    | top-k chunks     |
                    | (rules + style)  |
                    +--------+---------+
                             |
                             ▼
                    +------------------+
                    |     Planner      |
                    +--------+---------+
                             |
                             ▼
                    +------------------+
                    |   Implementer    |
                    +--------+---------+
                             |
                             ▼
                    +------------------+
                    |     Reviewer     |
                    +--------+---------+
                             |
                             ▼
                    +------------------+
                    |   Final Output   |
                    | plan / code /    |
                    | review           |
                    +------------------+
```

Retrieval provides shared context from both Wikipedia and an internal style guide, which is then passed through a simple Planner → Implementer → Reviewer pipeline.

---

## The Workflow

Each stage receives:
- The original task
- Retrieved evidence
- (For later stages) the output of the previous stage

- **Planner**: produces a structured implementation plan
- **Implementer**: generates code
- **Reviewer**: critiques the result

(Note that unlike a real Claude Code workflow, there is no looping or tool use — for now!)

---

## Prompt design

Of course, the behaviour of a system such as this one is largely determined by the prompts used at each stage.

Each agent receives the same inputs — the task, the retrieved evidence, and (for later stages) the output of the previous step — but is guided by a different prompt.

In practice, most of the behaviour of the system comes from how those prompts are written, so it’s worth looking at them directly. These code snippets show the prompts:

```python
def plan_task(question: str, evidence: list[dict]) -> str:
    system_prompt = (
        "You are Planner, a software planning agent. Produce a concise, structured "
        "implementation plan for a small Python application. When retrieved evidence "
        "contains implementation conventions, style guidance, file layout guidance, "
        "testing guidance, or CLI conventions, treat that guidance as authoritative "
        "unless it conflicts with the user's explicit requirements. Use retrieved "
        "domain evidence for domain-specific rules and behaviour."
        "Do not write code."
    )
    user_prompt = (
        f"Task: {question}\n\n"
        f"Retrieved evidence:\n{_format_evidence(evidence)}\n\n"
        "Return these sections only:\n"
        "1. Files\n"
        "2. Data structures\n"
        "3. Conventions to follow\n"
        "4. Game rules and flow\n"
        "5. Test strategy\n\n"
        "Requirements:\n"
        "- Extract concrete conventions from the retrieved evidence\n"
        "- Make the plan explicitly reflect retrieved file layout, style, CLI, and test conventions when present\n"
        "- Do not invent conventions that are not supported by the evidence\n"
        "- Keep it compact and implementation-ready"
    )
    return invoke_claude(system_prompt, user_prompt, max_tokens=900, temperature=0.0)


def implement_task(question: str, evidence: list[dict], plan: str) -> str:
    system_prompt = (
        "You are Implementer, a Python coding agent. Generate a complete, runnable, "
        "terminal-based Python application. When retrieved evidence contains "
        "implementation conventions, style guidance, file layout guidance, testing "
        "guidance, naming guidance, or CLI conventions, you must follow that guidance "
        "unless it conflicts with the user's explicit requirements. Do not silently "
        "replace retrieved conventions with your own defaults. Use retrieved domain "
        "evidence for gameplay rules and behaviour. Output only code files using the "
        "exact separator format === filename ===."
    )
    user_prompt = (
        f"Task: {question}\n\n"
        f"Retrieved evidence:\n{_format_evidence(evidence)}\n\n"
        f"Plan:\n{plan}\n\n"
        "Generate the full application now.\n\n"
        "Hard requirements:\n"
        "- Python only\n"
        "- prefer the standard library unless explicitly required otherwise\n"
        "- produce a complete, runnable application\n"
        "- ensure the application behaviour matches the task description\n"
        "- modular, readable, and compact implementation\n"
        "- include basic tests for core logic\n\n"
        "Domain behaviour:\n"
        "- derive all domain-specific behaviour strictly from the task and retrieved evidence\n"
        "- do not assume behaviour that is not supported by the task or evidence\n\n"
        "Retrieved evidence handling:\n"
        "- treat retrieved style and conventions as binding implementation guidance when present\n"
        "- prefer retrieved file layout, naming, structure, CLI, and test conventions over generic defaults\n"
        "- only depart from retrieved conventions if they conflict with the task requirements\n"
        "- do not explain the conventions; just implement them\n\n"
        "Output multiple files in one plain-text response using separators like:\n"
        "=== main.py ===\n"
        "...\n"
        "=== module.py ===\n"
        "...\n"
        "=== test_module.py ==="
    )
    return invoke_claude(system_prompt, user_prompt, max_tokens=4500, temperature=0.0)


def review_code(question: str, evidence: list[dict], code: str) -> str:
    system_prompt = (
        "You are Reviewer, a software review agent. Review generated Python code for "
        "correctness, completeness, and adherence to retrieved evidence. When "
        "retrieved evidence contains implementation conventions, style guidance, file "
        "layout guidance, testing guidance, naming guidance, or CLI conventions, "
        "treat those conventions as the review baseline unless they conflict with the "
        "user's explicit requirements. Be specific, concise, and deterministic."
    )
    user_prompt = (
        f"Task: {question}\n\n"
        f"Retrieved evidence:\n{_format_evidence(evidence)}\n\n"
        "Review the generated application. Focus on:\n"
        "- correctness\n"
        "- adherence to task requirements\n"
        "- adherence to retrieved style and conventions\n"
        "- mismatches with retrieved domain evidence\n"
        "- edge cases\n"
        "- structure and readability\n"
        "- test coverage\n\n"
        "Return short bullet points only. Call out specific convention violations when present.\n\n"
        f"Code:\n{code}"
    )
    return invoke_claude(system_prompt, user_prompt, max_tokens=1000, temperature=0.0)
```

---

## First Attempt

The initial experiment used retrieval to supply Wikipedia-style descriptions of Minesweeper.

Prompt:

> Build a playable Minesweeper game in Python.

The system produced a working implementation. However, rerunning the same prompt **without retrieval** produced nearly identical results.

The presence of Wikipedia-style evidence had little to no impact on:
- Code structure
- Implementation quality
- Behavior

This is a useful negative result. Minesweeper is a well-known problem, and the model already has strong prior knowledge of how to implement it. Supplying factual descriptions of the game did not introduce enough new information to change the output.

**Key takeaway:**
Retrieval does not improve generation if it only repeats what the model already knows.

---

## Second Attempt

The second experiment introduced a different kind of corpus: a coding style guide similar to what might exist in a software development company’s Wiki.

This time, the difference was clear.

### Without retrieval
- Monolithic structure (logic, UI, tests in one file)
- Large, multi-responsibility functions
- Missing docstrings
- Inconsistent validation

### With retrieval (style guide)
- Modular structure (`board.py`, `game.py`, `main.py`)
- Smaller, focused functions
- Docstrings and clearer naming
- Consistent validation patterns

Unlike Wikipedia, the style guide introduced constraints that were not already strongly encoded in the model’s default behavior. It acted as behavioural steering, shaping how the model applied its knowledge.

(Note that even with the style guide, though, while the model improved structure significantly, it did not apply the guidance 100% consistently — particularly around typing, documentation, and strict adherence to conventions. But that's a problem for another day!)

---

## Conclusion

This experiment shows that retrieval only helps when it adds information the model does not already reliably have.

In the first attempt, Wikipedia-style facts about Minesweeper had little impact because the model already knew how to implement the game. The retrieved evidence did not meaningfully change its behavior.

In the second attempt, the retrieved style guide introduced constraints on structure, naming, and testing. These were not strongly present in the model’s default behavior, and they produced a clear improvement in the output.

The broader lesson is that retrieval is not just about facts or constraints in isolation. In real systems, retrieval is often used to provide facts the model could not know from training data — such as internal business knowledge or recent information — or to supply conventions the model would not otherwise follow.

In both cases, retrieval is valuable for the same reason: it supplies information the model would not otherwise use, and therefore changes the result.

---

## What comes next

This workflow is a single pass: Planner → Implementer → Reviewer.

That’s enough to produce working code, but it has a clear limitation — the system cannot act on its own feedback. The reviewer identifies issues, but nothing uses that information to improve the result.

The natural next step is iteration.

Instead of a single pass, the system should loop:
generate → review → refine → repeat

This brings it closer to real coding agents, which improve code over multiple steps using feedback from reviews, tests, or execution.

Extending this pipeline into a loop is the point where it stops being a structured prompt flow and becomes a true coding agent.
