---
layout: post
title: "Experiments in Agentic AI, Part I: Agentic Research Analyst"
date: 2025-12-30
author: Alex Harvey
tags: agentic-ai rag multi-agent
---

- ToC
{:toc}

## Series directory

This post is **Part I** of a multi-part series documenting my progress building agentic AI workflows — systems where multiple LLMs ("agents") collaborate on a larger piece of work.  If you want to jump ahead, here's the full sequence:

- [**Part I: Agentic Research Analyst**](http://alex-harvey-z3q.github.io/2025/12/30/experiments-in-agentic-ai-part-i.html) (this page)
  Building the foundation: a minimal Retrieval-Augmented Generation (RAG) layer that all later agents depend on.

- [**Part II: Adding Agents**](https://alex-harvey-z3q.github.io/2025/12/30/experiments-in-agentic-ai-part-ii.html).
  Introducing planner, researcher, analyst, writer, and reviewer agents — and observing how things break once multiple models are chained together.

- [**Part III: Evidence, Gates, and Enforcing Truthfulness**](https://alex-harvey-z3q.github.io/2026/01/02/experiments-in-agentic-ai-part-iii.html)
  Replacing free-text “notes” with structured evidence, tightening contracts between agents, and making the system fail conservatively instead of hallucinating.

---

## Introduction

In this introductory post, I'm building a small but serious project: an **AI research analyst** that takes a question about something — in this demo, Beatles lyrics — and produces a structured, executive-style brief with sources, reasoning steps, and a basic quality review.

Note that this is not about chatbots. It’s about doing *agentic AI* in practice — finding out what multiple specialised AI agents coordinating together can actually do, not what they do in flashy demos.

At a high level, the system I’m working toward includes distinct agents responsible for planning, research, analysis, writing, and review. Each “agent” is essentially just a separate prompt sent to a single LLM.

This post focuses on the foundation: a minimal Retrieval-Augmented Generation (RAG) layer. This retrieval capability is the shared tool that later agents — especially the researcher (to gather evidence) and the reviewer (to verify it) — will rely on.

If you want to follow along with the implementation, all of the source code for this project lives here:

> **https://github.com/alex-harvey-z3q/agentic-analyst**

This post is written from the perspective of a non-expert learning by building, and it’s aimed at readers who want to understand what’s really going on under the hood.

## The end goal

In its final form, the workflow looks roughly like this:

- A user asks a research question
- A **Planner agent** breaks it into sub-tasks
- A **Research agent** gathers evidence (from the web and local documents)
- An **Analysis agent** synthesises findings
- A **Writer agent** produces a report
- A **Reviewer agent** checks for hallucinations (made-up facts), citations, factual accuracy, and tone

Every step is logged so it’s possible to see what happened, in what order, and why.

You don’t need to understand how all of these agents work yet. This post focuses on one foundational piece that several of them will later share.

---

## The architecture (conceptual)

To make that a bit more concrete, here’s a simplified view of the overall architecture I’m building toward:

```
┌────────────────────────────────┐      ┌───────────────────────────────────┐
│            LangGraph           │◄────►│               Corpus              │
│ src/graph.py                   │      │ data/corpus/*.txt                 │
│ (workflow + AgentState flow)   │      │ → embeddings → Chroma (tools.py)  │
└───────────────┬────────────────┘      └───────────────────────────────────┘
                │
                v
       ┌────────────────────────┐
       │     Planner Agent      │
       │ src/nodes/planner.py   │
       └───────────┬────────────┘
                   │
                   v
       ┌────────────────────────┐
       │   Researcher Agent     │
       │ src/nodes/researcher.py│
       └───────────┬────────────┘
                   │
                   v
       ┌────────────────────────┐
       │     Analyst Agent      │
       │ src/nodes/analyst.py   │
       └───────────┬────────────┘
                   │
                   v
       ┌────────────────────────┐
       │      Writer Agent      │
       │ src/nodes/writer.py    │
       └───────────┬────────────┘
                   │
                   v
       ┌────────────────────────┐
       │    Reviewer Agent      │
       │ src/nodes/reviewer.py  │
       └────────────────────────┘
```

It looks like a lot. In this post, however, we’re only concerned with the **retrieval layer** on the right-hand side — the part that turns a pile of documents into something the agents can actually use.

---

## Why start with RAG?

Before adding multiple agents, I want to be confident that a single model can answer a single question **grounded in retrieved evidence**.

Agentic systems amplify whatever you give them. If the system starts with weak or misleading information, adding more agents just makes it reach the wrong conclusion faster.

That’s why this project starts with **Retrieval-Augmented Generation (RAG)** — a setup where the language model is forced to answer using retrieved source text, rather than relying purely on its internal training data.

So before adding agents, I want a system where:

- Retrieved text is explicit
- Prompt construction is visible
- Failure modes are obvious

So, a very simple RAG pipeline, built by hand.

---

## The CLI: a single grounded loop

```python
def answer_question(question: str) -> str:
    context = rag_search(question)
    user_prompt = f"Question:\n{question}\n\nContext:\n{context}"
    return call_llm(SYSTEM, user_prompt)
```

Right now, the system does exactly three things:

1. Retrieves relevant text chunks
2. Combines them with the question (in the variable `context`)
3. Asks the model to answer

The system prompt is short but important:

> *Use the provided context faithfully.*

That single instruction becomes the contract that later **Reviewer agents** will enforce.

---

## Configuration in one place

```python
MODEL_NAME = "gpt-4.1-mini"
client = OpenAI(api_key=OPENAI_API_KEY)
```

All model and API configuration lives in one place. This makes it easy to swap models or tune cost versus quality later, without refactoring core logic.

---

## Building a local knowledge base

The “corpus” (the collection of documents the system can search) is deliberately boring: a directory of `.txt` files.

```python
for path in corpus_dir.glob("*.txt"):
    loader = TextLoader(str(path), encoding="utf-8")
    docs.extend(loader.load())
```

In a larger or more mature project, this corpus might be produced by a scraping pipeline or PDF parsing step. Here I keep it simple: just text that I can inspect and version control.

Documents are split into overlapping chunks:

```python
RecursiveCharacterTextSplitter(
    chunk_size=800,
    chunk_overlap=150,
)
```

The idea is that smaller chunks improve retrieval precision, while overlap helps preserve context.

---

## Embeddings: How the system understands meaning

```python
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
```

An embedding is just a long list of numbers that represents the meaning of a piece of text.

Each chunk is embedded into a vector so that semantic similarity can be computed. Put another way, embeddings let the system retrieve chunks that express the same concept, even if they don’t share the same words.

So when the system searches, it’s not asking:

> “Which documents contain these words?”

It’s asking:

> “Which chunks are *about* the same thing as this question?”

This is what allows RAG to surface conceptually relevant text, rather than just passages that happen to share keywords.

---

## Retrieval is the bottleneck

```python
docs = _vectordb.similarity_search(query, k=5)
```

When the system is asked a question, it first searches the corpus and selects up to five text chunks that seem most relevant.

These chunks are the only information the language model is allowed to use when answering. If something isn’t in those five chunks, the model will never see it.

Limiting retrieval to five chunks is intentional. It forces the system to surface the most relevant evidence instead of dumping large amounts of loosely related text into the prompt.

If the retrieved chunks don’t contain enough information to answer the question well, the solution usually isn’t to “make the model smarter”. The solution is to improve what gets retrieved — by changing how documents are split, improving the corpus, or rephrasing the question.

Every more advanced agent added later will depend on this same retrieval step. If retrieval is weak, all downstream reasoning will be weak as well.

---

## Calling the model

```python
resp = client.responses.create(
    model=MODEL_NAME,
    input=[
        {"role": "system", "content": system_prompt},
        {"role": "user",   "content": user_prompt},
    ],
)
```

The model sees:

- Instructions
- A question
- Retrieved evidence

There’s no hidden browsing, memory, or tools involved at this stage.

---

## Why this matters for agentic AI

There’s a temptation to jump straight into more complex agent setups — planners that decompose tasks, graphs that wire agents together, or recursive reasoning loops.

But agentic systems don’t eliminate complexity — they **move it**.

This RAG layer is the bedrock:

- Research agents will call it
- Reviewer agents will audit its outputs
- Planner agents will decide when to invoke it

If this layer is unclear or unreliable, everything above it becomes fragile.

---

## What comes next

In **Part II**, I’ll introduce a first pass at an **agentic pipeline**:

- A **Planner** to decompose questions
- A **Researcher** to retrieve and summarise evidence
- An **Analyst** to synthesise patterns
- A **Writer** to produce a structured report
- A **Reviewer** to sanity-check the output

These agents are coordinated using a simple **LangGraph state machine** — a way of explicitly defining how agents hand work off to each other.
