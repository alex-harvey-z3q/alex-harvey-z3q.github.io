---
layout: post
title: "Experiments in Agentic AI, Part II: Adding Agents"
date: 2025-12-30
author: Alex Harvey
tags: agentic-ai multi-agent langgraph
---

- ToC
{:toc}

## Introduction

In Part I, I built a minimal Retrieval‑Augmented Generation (RAG) loop: one question in, relevant text retrieved, a grounded answer out.

The retrieval layer is now my infrastructure to build agents on. In this post, I do that, and start adding agents on top of it — beginning with the simplest and most important one: the Planner.

If you want to follow along with the actual code, everything in this post lives here:

> **https://github.com/alex-harvey-z3q/agentic-analyst**

As before, this is written from the perspective of a non‑expert learning by building, and aimed at readers who want to understand what's really going on under the hood.

---

## What "adding agents" means here

Before looking at the code, it's worth talking about what an *agent* actually is.

In this project, an agent is not some new kind of AI. There's no autonomy, no background processes, and no magic. An agent is simply:

- a Python function,
- with a role‑specific system prompt,
- that reads from shared state and writes its output back.

Agents are called explicitly and sequentially. The benefit isn't autonomy; it's separation of responsibilities.

---

## Shared state

All agents in this system communicate through a single shared state object, defined in `graph_state.py`.

Rather than passing lots of parameters between functions, each agent receives the entire state, reads the fields it cares about, and writes its own outputs back into it. Conceptually, the state is just a Python dictionary — but with a deliberately agreed structure.

Here's the definition:

```python
from typing import List, TypedDict

class AgentState(TypedDict, total=False):
    # Note that total=False makes fields in the TypedDict optional.

    # Original user question
    question: str

    # Planner output
    sub_tasks: List[str]

    # Researcher output
    research_notes: List[str]

    # Analyst output
    analysis: str

    # Writer output
    draft_report: str

    # Reviewer output
    final_report: str

    # Debug / trace messages
    logs: List[str]
```

This state acts as a **contract between agents**.

Each agent is responsible for:
- reading only the fields it needs,
- writing only the fields it owns,
- and appending a short entry to `logs` describing what it did.

For example:
- the Planner reads `question` and writes `sub_tasks`,
- the Researcher reads `sub_tasks` and writes `research_notes`,
- the Writer reads `analysis` and writes `draft_report`,
- the Reviewer reads `draft_report` and writes `final_report`.

No agent is allowed to silently modify another agent's output.

This design turns the workflow into something you can reason about step by step. At any point, you can print the state and see:
- what information has been introduced,
- which agent introduced it,
- and what decisions were made along the way.

That's especially important with LLM-based systems, where behaviour can otherwise feel opaque or “magical". By forcing everything through an explicit shared state, failures become visible rather than hidden — which makes debugging, iteration, and learning much easier.

---

## The Planner agent

### About the Planner agent

The Planner is deliberately boring — and that's a good thing.

Its job is not to answer the user's question. It doesn't do any research. It simply takes a broad question and breaks it into a small number of concrete research tasks.

If this were a human team, the Planner might be the person who turns a Jira story into a to‑do list.

---

### The Planner source code

```python
from __future__ import annotations

from typing import List

from graph_state import AgentState
from tools import call_llm

SYSTEM = """You are a planning agent.
Break the user's research question into 3–5 concrete sub-tasks that a researcher could execute.

Rules:
- Keep each sub-task short (one line).
- Make them specific and actionable.
- Return ONLY a numbered list (1., 2., 3., ...). No extra text.
"""


def _parse_numbered_lines(text: str) -> List[str]:
    tasks: List[str] = []
    for line in text.splitlines():
        s = line.strip()
        if not s:
            continue
        if s[0].isdigit() and (". " in s[:4] or ") " in s[:4]):
            tasks.append(s)
    return tasks


def planner_node(state: AgentState) -> AgentState:
    question = state["question"]

    plan_text = call_llm(
        system_prompt=SYSTEM,
        user_prompt=f"Research question:\n{question}\n\nCreate the sub-tasks now.",
    )

    sub_tasks = _parse_numbered_lines(plan_text)

    # See notes below!
    if not sub_tasks:
        sub_tasks = [
            line.strip("- ").strip()
            for line in plan_text.splitlines()
            if line.strip()
        ][:5]

    state["sub_tasks"] = sub_tasks
    state.setdefault("logs", []).append(f"[planner]\n{plan_text}")
    return state
```

The key ideas here are: be very specific about what you ask the model to return, assume it will sometimes ignore you, and keep a record of what it actually produced.

---

### A note about numbered lists!

One thing that surprised me early on is how often LLMs ignore formatting instructions, even when they're written very clearly. For example, the Planner prompt includes this instruction:

> Return ONLY a numbered list (1., 2., 3., ...). No extra text.

Even with that constraint, the model will sometimes return a bulleted list, or mix formatting styles. Because later steps depend on this output, the code has to be defensive and handle these cases explicitly. So that's what this bit is about:

```python
if not sub_tasks:
    sub_tasks = [
        line.strip("- ").strip()
        for line in plan_text.splitlines()
        if line.strip()
    ][:5]
```

This seems to be one of the less glamorous problems that gets glossed over in the hype around agentic AI. Building reliable workflows on top of models that are fundamentally probabilistic — and sometimes disobedient — requires a lot of careful engineering!

### Testing the Planner agent

Before wiring the Planner into a full pipeline, I test it in isolation.

```python
from nodes.planner import planner_node

if __name__ == "__main__":
    question = "What themes and lyrical motifs recur across The Beatles' songs?"

    print("\nQUESTION:")
    print(question)

    state = {
        "question": question,
        "logs": []
    }

    out = planner_node(state)

    print("\nSUB_TASKS:")
    for task in out.get("sub_tasks", []):
        print("-", task)

    print("\nLOGS:")
    for log in out.get("logs", []):
        print(log)
```

This isn't a unit test in the traditional sense. It's an inspection tool, designed to make the model's behaviour visible.

Here's what it looks like when I run it:

```
% python src/test_planner.py

QUESTION:
What themes and lyrical motifs recur across The Beatles' songs?

SUB_TASKS:
- 1. Compile a comprehensive list of all Beatles songs and their lyrics.
- 2. Identify and categorize recurring themes present in the lyrics.
- 3. Analyze lyrical motifs, such as symbolism, phrases, and imagery, within the songs.
- 4. Compare themes and motifs across different albums and time periods.
- 5. Summarize findings to highlight the most prevalent themes and motifs in The Beatles' music.

LOGS:
[planner]
1. Compile a comprehensive list of all Beatles songs and their lyrics.
2. Identify and categorize recurring themes present in the lyrics.
3. Analyze lyrical motifs, such as symbolism, phrases, and imagery, within the songs.
4. Compare themes and motifs across different albums and time periods.
5. Summarize findings to highlight the most prevalent themes and motifs in The Beatles' music.
```

---

## The rest of the agents

With the Planner working, the remaining agents follow the same pattern:

- **Researcher**: gathers evidence using the RAG layer
- **Analyst**: synthesises patterns across notes
- **Writer**: produces a readable report
- **Reviewer**: checks for hallucinations and weak claims.

Each agent has one responsibility. The complexity comes from coordination, not from any one agent being clever.

---

## Testing the whole pipeline

So let's finally run this thing:

```
% python src/test_reviewer.py

QUESTION:
What themes and lyrical motifs recur across The Beatles' songs?

FINAL REPORT:
## Issues found

- Some quoted lyrics in the draft report do not appear or cannot be verified in the research notes provided, e.g., quotes like "I've just seen a face," "You have changed your mind," "Love has a nasty habit / Of disappearing overnight," "Falling... she keeps calling me back," "The king of Marigold was in the kitchen," and others are mentioned but the research notes do not contain these exact excerpts or confirm their source from Beatles songs.
- A few claims about thematic evolution and lyrical content (e.g., psychedelic imagery, social awareness, philosophical meditation) are reasonable but not fully supported by the relatively limited lyric excerpts and examples documented.
- The draft report uses confident language ("The Beatles' lyrics transition from...") that could be moderated given the noted limitations about partial data and incomplete song coverage.
- The motif "Falling and Being Called Back" is discussed in detail, but corresponding precise lyrics in the research notes are missing or not clearly attributed to any Beatles song.
- The claim that "rare but significant outliers—dark psychological themes and direct social commentary" appear lacks direct lyric examples explicitly tied to social commentary besides a brief mention of "Revolution 1" in the research notes, which is not referenced in the draft.
- The "Domestic and Whimsical Narrative" motif citing "The king of Marigold was in the kitchen" is not corroborated by research notes and thus should be flagged as unsupported.
- The tone in the draft is generally comprehensive and somewhat confident; this could be softened to acknowledge dataset limits more explicitly.
- The structure is mostly clear and logical, but some sections repeat or overlap in theme discussion and motif listing; tightening could improve clarity.
- The draft mentions a comprehensive thematic progression through early, mid, and late Beatles periods; while some support is present, data limitations mean this progression should be presented more cautiously.

## Final revised report

# Executive Summary

This report summarizes recurring themes and lyrical motifs identified within a subset of The Beatles' songs, based on partial lyric excerpts and thematic analysis. It highlights central motifs including love, despair, nature, perception, and spirituality. Within the available data, the Beatles' lyrics appear to evolve from straightforward romantic and personal subjects toward more poetic and abstract reflections featuring pastoral imagery, meditative spirituality, and occasional experimental playfulness. Some instances suggest darker emotional content and hints of social commentary, though these are less well represented in the data. The report also notes limitations due to incomplete lyric coverage and partial contextual information.

# Key Themes

- **Love and Relationships**
  The lyrics reviewed often explore romantic love ranging from joyful discovery (e.g., "I've just seen a face" cited in research notes) to emotional conflict and distance (e.g., "You have changed your mind"). There are philosophical reflections as well, such as the line "Love is old, love is new," implying a broad meditation on love's nature.

- **Despair, Loneliness, and Emotional Burden**
  Some excerpts contain expressions of alienation and distress, including phrases like "Feel so suicidal," and "I'm lonely," as well as references to enduring emotional weight ("Boy, you're gonna carry that weight a long time"), indicating recurring motifs of internal struggle.

- **Nature and Cosmic Identity**
  Pastoral and natural imagery appears frequently (e.g., "Mother Nature's son," "Blackbird singing in the dead of night"), often symbolizing peace or spiritual reflection. Cosmic metaphors such as "I am of the Universe" suggest themes extending beyond the personal.

- **Perception and Communication**
  Recurrent calls for understanding and recognition (e.g., "Tell me what you see," "Open up your eyes now") highlight desires for emotional connection and validation.

- **Musical and Emotional Expression**
  Music is portrayed both as subject and medium for emotional expression, for example in "While my guitar gently weeps." Experimental lyrical playfulness is found in self-referential lines like "You may think the chords are going wrong," illustrating musical innovation.

- **Spirituality and Acceptance**
  Eastern-inspired mantras ("Jai guru deva Om") and affirmations ("Nothing's gonna change my world") point to themes of meditation, acceptance, and calm.

- **Change, Nostalgia, and Personal Growth**
  Themes of transformation, loss, and reflection occur in lines such as "You've changed" and "In my life," illustrating evolving understandings of relationships and self.

# Motifs & Imagery

- **Natural and Pastoral Imagery**
  Recurring images include animals, fields, and elements of nature (e.g., “blackbird," “sky is blue"), serving as metaphors for emotional states.

- **Repetition for Emphasis**
  Phrases like "Too much, too much," "Carry that weight," and "Roll up" are repeated to intensify emotional or thematic resonance.

- **Vision and Perception Imagery**
  Frequent references to seeing or being seen enhance themes of empathy and recognition (“Open up your eyes," “Tell me what you see").

- **Musical Metaphors**
  Lyrics such as "While my guitar gently weeps" employ music as a symbol of sorrow and communication.

- **Surreal and Abstract Imagery**
  Some lyrics incorporate psychedelic or meta-musical elements (e.g., "Shoot me," "You may think the chords are going wrong"), reflecting experimental approaches.

- **Domestic and Whimsical Narrative**
  The motif of whimsical storytelling is suggested but not clearly supported by the lyrics available (e.g., "The king of Marigold was in the kitchen" is not verified in the notes), so this should be treated cautiously.

# Evolution Over Time (Based on Partial Data)

- **Early Period (up to Rubber Soul):**
  Lyrics tend to focus on

LOGS:
[planner]
1. Compile a comprehensive list of The Beatles' songs and their lyrics.
2. Identify and categorize recurring themes and motifs within the lyrics.
3. Analyze the frequency and context of each theme or motif across different albums and periods.
4. Compare thematic changes over time in relation to the band's evolution and external influences.
5. Summarize findings with examples to illustrate key recurring themes and lyrical motifs.
[researcher] wrote 5 note blocks
[analyst] analysis produced
[writer] draft produced
[reviewer] final review completed
```

## Some comments on failures

If read closely, the output reveals my pipeline has failed in a number of ways.  None of these are unusual either, apparently; these are the kinds of problems that only show up once you start chaining multiple model calls together.

### 1. The reviewer spotted problems, but didn't fully fix them

The reviewer correctly identified unsupported lyric quotes, overconfident language, and weakly supported motifs. That's exactly what it was asked to do.

However, many of those same claims still appear in the final revised report. This isn't because the reviewer missed them — it's because it was asked to *both* critique and rewrite a long document in a single pass. In practice, the model often hedges language rather than strictly removing every problematic sentence.

### 2. Tone was corrected more reliably than content

The reviewer does a good job softening the tone of the report (“appears to", “within the available data"), but this doesn't always translate into stricter factual enforcement.

This is a common pattern: models are very good at changing *how* something is said, and less reliable at ensuring *what must not be said* is completely removed.

### 3. The report contains internal contradictions

Some motifs are discussed and then immediately caveated as unsupported. From a human editor's perspective, this is inconsistent. From the model's perspective, it's the result of trying to satisfy conflicting instructions: produce a complete report, but also be conservative and flag limitations.

### 4. The truncated section is a stress signal

The report stops mid-sentence in the “Evolution Over Time" section. This usually happens when token limits, uncertainty, and conservative prompting collide. Rather than inventing content to fill the gap, the model simply stops.

While this looks messy, it's arguably safer than confidently hallucinating a conclusion.

### 5. Planning decisions cascaded downstream

One of the planner's sub-tasks asked for a “comprehensive" overview of Beatles lyrics — something the partial corpus can't support. That mismatch propagates forward, forcing later agents to hedge, overgeneralise, or contradict themselves.

This highlights how early planning decisions quietly constrain everything that follows.

### 6. Failure, but the right kind

Despite these issues, the system doesn't hide its uncertainty. It flags missing evidence, exposes its own limitations, and fails noisily rather than smoothly.

That's an important lesson: adding agents doesn't eliminate errors — it changes how and where they appear.

---

## What comes next

In Part III, I'll start wiring these agents together more formally and look at how orchestration changes the system's behaviour.

## References

Further reading:

- Why language models hallucinate (OpenAI) https://openai.com/index/why-language-models-hallucinate/
- Hallucination is Inevitable: An Innate Limitation of Large Language Models (arXiv) https://arxiv.org/abs/2401.11817
- A Taxonomic Survey of Hallucinations in Large Language Models (MDPI) https://www.mdpi.com/2673-2688/6/10/260
- Hallucination (Artificial Intelligence) – overview and references (Wikipedia) https://en.wikipedia.org/wiki/Hallucination_(artificial_intelligence)
- Why LLM outputs get truncated or stop mid-sentence (Stack Overflow discussion) https://stackoverflow.com/questions/77061898/incomplete-output-with-llm-with-max-new-tokens
- Understanding stopping criteria and truncated LLM outputs (Medium) https://medium.com/@hafsaouaj/when-do-llms-stop-talking-understanding-stopping-criteria-6e96ef01835c
- Overcoming output token limits in LLMs (Medium) https://medium.com/@gopidurgaprasad762/overcoming-output-token-limits-a-smarter-way-to-generate-long-llm-responses-efe297857a76
- Survey and analysis of hallucinations in LLMs (PMC / academic paper) https://pmc.ncbi.nlm.nih.gov/articles/PMC12518350/
