---
layout: post
title: "Experiments in Agentic AI, Part III: Evidence, Gates, and Enforcing Truthfulness"
date: 2026-01-02
author: Alex Harvey
tags: agentic-ai multi-agent rag reliability
---

- ToC
{:toc}

## Introduction

In Part II, I added multiple agents on top of a shared RAG layer and watched the system fail in interesting ways.

The most important lesson was this:

> **notes are not a contract**.

We briefly introduced contracts in Part II. By a contract here, I mean an explicit agreement about what data is allowed to pass from one agent to the next, in what shape, and what downstream agents are allowed to trust (because the code enforces it).

Free text passed between agents can look structured, but it isn't. Once you chain multiple model calls together, anything that isn't explicit, machine-checkable, or enforced will eventually be ignored, misunderstood, or hallucinated.

This post is about the changes I made to address that. I have tightened the contracts between agents so unsupported claims get weeded out.

---

## The core shift: from notes to evidence

Originally, the Researcher produced `research_notes`: human‑readable summaries with quotes sprinkled in.

That turned out to be a dead end.

Later agents:
- paraphrased instead of quoting,
- "rounded off" lyrics,
- or confidently reused claims the reviewer had already flagged as unsupported.

So I replaced notes with **structured evidence items**.

Each evidence item is a small dictionary with a fixed shape:

```json
{
  "task": "Find lyrics about loneliness",
  "song": "Eleanor Rigby",
  "quote": "all the lonely people",
  "theme": "loneliness / isolation"
}
```

This has made a difference.

Evidence is now:
- **atomic** (i.e. each item represents one specific quote from one specific song)
- **inspectable** (you can print it),
- **machine‑checkable** (JSON, not text),
- and **traceable** (it came from retrieval, not vibes!).

This is the foundation for enforcing truthfulness later on. In other words, "don’t claim anything we can’t point to in the corpus".

---

## Forcing the Researcher to fail closed (if in doubt, output nothing)

The Researcher agent used to return Markdown bullets. Now it must return valid JSON, and nothing else.

If it can't extract evidence from the retrieved context, it returns an empty list. That means:

- no fallback prose,
- no "best guess",
- no creative paraphrasing.

The rule is simple:

> *If it isn't parseable, it isn't trusted.*

In practice this means:

- malformed output is ignored,
- unsupported claims simply never enter the system,
- and downstream agents are forced to stay cautious when evidence is lacking.

---

## Forcing downstream agents to only use quoted text

With evidence structured, the next step is to bind downstream agents to it.

Both the Analyst and Writer are now constrained to:

- only make claims supported by evidence items,
- include short verbatim quotes,
- explicitly acknowledge gaps when evidence is missing.

They can no longer sound comprehensive without backing.

The outputs are often shorter — but they're also more honest.

---

## Who reviews the reviewer?

In Part II, I asked a single Reviewer agent to:

1. critique the draft,
2. remove unsupported claims,
3. and rewrite the report.

That turned out to be too much. LLMs do much better when they are asked to do one thing at a time.

In my case, the model would *identify* bad content, but then quietly leave some of it in.

So I split review into two stages.

### 1. Validator agent

The Validator:

- compares the draft against evidence,
- removes unsupported sentences,
- deletes entire sections if necessary,
- and reports what was removed.

It does **not** try to improve style.

### 2. Editor agent

Only after validation do I run an Editor agent, whose job is purely:
- clarity,
- structure,
- and readability.

The Editor is explicitly forbidden from adding claims or quotes.

This separation dramatically reduced the "criticises but keeps it anyway" failure mode.

---

## Retrieval layer issues: correct corpus, wrong answers

Once I started enforcing evidence contracts, a different problem showed up — not in the agents, but in retrieval itself.

The system began claiming there was "limited data" for early Beatles albums, even though the corpus contained every lyric. At first this looked like a hallucination. It wasn’t.

The problem was simpler: the retriever just wasn't finding the relevant lines. If a lyric never made it into retrieval, it never became evidence — rightly.

### 1. The corpus shape was wrong

Originally, `build_vectorstore()` assumed the corpus was a directory of files:

```python
for path in corpus_dir.glob("*.txt"):
    loader = TextLoader(str(path), encoding="utf-8")
    docs.extend(loader.load())
```

But I had made the corpus a single file with repeated blocks:

```text
lyrics/Album/Song.txt
===
<lyrics>
===
```

As a result, the retriever was embedding large, mixed documents instead of one song at a time.

#### Fix: make the document boundary explicit

I introduced a proper parser:

```python
def load_beatles_lyrics_corpus(corpus_path: str) -> List[Document]:
    """
    Parse beatles_lyrics.txt into one Document per song.
    """
    # Parsing logic omitted.
    ...
    docs.append(
        Document(
            page_content=lyrics,
            metadata={
                "song": song,
                "album": album,
                "source_path": source_path,
            },
        )
    )
```

---

### 2. Metadata was implicit and unreliable

Before the refactor, song and album attribution was inferred downstream — or worse, hallucinated.

Once chunking enters the picture, this becomes impossible to fix later.

#### Fix: attach metadata before chunking

```python
split_docs = splitter.split_documents(song_docs)
```

Because metadata is attached to the parent `Document`, LangChain propagates it to every chunk. (Note that LangChain `Document` objects are just text + metadata.)

That single change eliminated an entire class of attribution errors.

---

### 3. Retrieval returned strings, not evidence

The original retrieval API returned a blob of text:

```python
def rag_search(query: str, k: int = 5) -> str:
    docs = _vectordb.similarity_search(query, k=k)
    return "\n\n".join(d.page_content for d in docs)
```

That design choice made it impossible to:

- inspect results
- test retrieval behaviour
- enforce evidence contracts downstream

#### Fix: split retrieval from formatting

```python
def rag_retrieve(query: str, k: int = 5) -> List[Document]:
    vectordb = _get_vectordb()
    return vectordb.similarity_search(query, k=k)
```

```python
def rag_search(query: str, k: int = 5) -> str:
    docs = rag_retrieve(query, k=k)
    return "\n\n".join(d.page_content for d in docs)
```

Now:

- agents consume structured `Document` objects
- presentation becomes a thin wrapper
- retrieval is testable in isolation.

---

### Tests: forcing retrieval to prove itself

#### `test_tools.py`

I then added unit tests in `test_tools.py`.

This test locks down the corpus contract and metadata propagation:

```python
def test_load_beatles_lyrics_corpus_parses_blocks(...):
    docs = tools.load_beatles_lyrics_corpus(...)
    assert d0.metadata["song"] == "Because"
    assert "Because the world is round" in d0.page_content
```

It also verifies that metadata survives chunking:

```python
songs = {d.metadata.get("song") for d in captured["split_docs"]}
assert "Because" in songs
```

#### `test_metadata.py`

Then I added a second test to allow me to inspect metadata generation:

```python
docs = rag_retrieve(q, k=5)
for d in docs:
    print(d.metadata, d.page_content[:120])
```

It answers the most important debugging question in retrieval systems:

> *What evidence did we actually retrieve?*

---

## Rerunning the pipeline

After all our fixes, let's run it again:

```
% python src/test_reviewer_editor.py

QUESTION:
What themes and lyrical motifs recur across The Beatles' songs?

VALIDATED REPORT (input to editor):
## Issues removed
- Removed the quote "She thinks of him And so she dresses in black" (Julia) from the Loneliness and Emotional Struggle theme because the evidence attributes this quote to "Baby's in Black," not "Julia."
- Removed the quote "Baby's in black and I'm feeling blue" (Julia) from the Loneliness and Emotional Struggle theme because the evidence attributes this quote to "Baby's in Black," not "Julia."

## Validated report
# Executive summary
The Beatles' lyrics recurrently explore themes of love and relationships, loneliness and emotional struggle, nature and seasons, dreams and imagination, and travel and movement. These themes are supported by vivid motifs and imagery such as affirmations of love, grief and loss, isolation, pastoral nature scenes, surreal dreamscapes, and cultural/geographic references. The evidence highlights the band's lyrical range from intimate emotional states to expansive imaginative and worldly experiences.

# Key themes

**Love and Relationships**
Expressions of devotion, faithfulness, universal love, and grief over loss appear frequently.
- "You know I love you" (Love Me Do)
- "I'll always be true" (Love Me Do)
- "All you need is love" (All You Need Is Love)
- "She thinks of him" (Baby's in Black)
- "And though he'll never come back" (Baby's in Black)
- "And from above you sent us love" (Mr. Moonlight)

**Loneliness and Emotional Struggle**
Feelings of isolation, despair, and sadness are prominent, often linked to love and loss.
- "Ah, look at all the lonely people" (Eleanor Rigby)
- "Wearing a face that she keeps in a jar by the door" (Eleanor Rigby)
- "Yes, I'm lonely Wanna die" (For No One)
- "Feel so suicidal Even hate my rock and roll" (For No One)

**Nature and Seasons**
Pastoral and natural imagery evoke calm, setting, and mood.
- "Sit beside a mountain stream" (Mother Nature's Son)
- "Find me in my field of grass" (Mother Nature's Son)
- "Swaying daisies sing" (Mother Nature's Son)
- "A lazy song beneath the Sun" (Mother Nature's Son)
- "You came to me one summer night" (Mr. Moonlight)

**Dreams and Imagination**
Surreal and dreamlike imagery blends reality with fantasy.
- "from your beam you made my dream" (Mr. Moonlight)
- "Lives in a dream" (Eleanor Rigby)
- "Picture yourself in a boat on a river" (Lucy in the Sky with Diamonds)
- "Cellophane flowers of yellow and green" (Lucy in the Sky with Diamonds)
- "Climb in the back with your head in the clouds" (Lucy in the Sky with Diamonds)

**Travel and Movement**
Exploration, cultural experience, and nostalgia for places are reflected in lyrics.
- "Oh, show me round your snow-peaked mountains way down south" (Back in the U.S.S.R.)
- "Take me to your daddy's farm" (Back in the U.S.S.R.)
- "Let me hear your balalaikas ringing out" (Back in the U.S.S.R.)
- "Can you take me back where I've been from?" (Cry Baby Cry)

# Motifs & imagery

- **Love and Devotion:** "You know I love you," "I'll always be true"
- **Loss and Grief:** "She thinks of him," "And though he'll never come back"
- **Loneliness:** "Ah, look at all the lonely people," "Wearing a face that she keeps in a jar by the door"
- **Nature Elements:** "Sit beside a mountain stream," "Swaying daisies sing," "You came to me one summer night"
- **Dreamlike and Surreal Imagery:** "Picture yourself in a boat on a river," "Cellophane flowers of yellow and green," "Climb in the back with your head in the clouds"
- **Cultural and Geographic References:** "snow-peaked mountains," "balalaikas ringing out," "daddy's farm"

# Caveats (evidence limits)
- No evidence was found regarding social commentary or political themes.
- Limited data on motifs related to time, change, or personal growth.
- The analysis does not cover lyrical or musical structures such as refrains or metaphors beyond thematic content.
- Evolution of themes across different Beatles albums or periods is not addressed due to current evidence scope.

FINAL REPORT (editor output):
## Issues removed
- Removed the quote "She thinks of him And so she dresses in black" (Julia) from the Loneliness and Emotional Struggle theme because the evidence attributes this quote to "Baby's in Black," not "Julia."
- Removed the quote "Baby's in black and I'm feeling blue" (Julia) from the Loneliness and Emotional Struggle theme because the evidence attributes this quote to "Baby's in Black," not "Julia."

## Validated report

# Executive Summary
The Beatles' lyrics consistently explore themes of love and relationships, loneliness and emotional struggle, nature and seasons, dreams and imagination, and travel and movement. These themes are supported by vivid motifs and imagery, including affirmations of love, expressions of grief and loss, feelings of isolation, pastoral nature scenes, surreal dreamscapes, and cultural or geographic references. The evidence demonstrates the band's lyrical range, spanning intimate emotional states to expansive imaginative and worldly experiences.

# Key Themes

**Love and Relationships**
Frequent expressions of devotion, faithfulness, universal love, and grief over loss.
- "You know I love you" (Love Me Do)
- "I'll always be true" (Love Me Do)
- "All you need is love" (All You Need Is Love)
- "She thinks of him" (Baby's in Black)
- "And though he'll never come back" (Baby's in Black)
- "And from above you sent us love" (Mr. Moonlight)

**Loneliness and Emotional Struggle**
Prominent feelings of isolation, despair, and sadness, often connected to love and loss.
- "Ah, look at all the lonely people" (Eleanor Rigby)
- "Wearing a face that she keeps in a jar by the door" (Eleanor Rigby)
- "Yes, I'm lonely Wanna die" (For No One)
- "Feel so suicidal Even hate my rock and roll" (For No One)

**Nature and Seasons**
Pastoral and natural imagery that evokes calm, setting, and mood.
- "Sit beside a mountain stream" (Mother Nature's Son)
- "Find me in my field of grass" (Mother Nature's Son)
- "Swaying daisies sing" (Mother Nature's Son)
- "A lazy song beneath the Sun" (Mother Nature's Son)
- "You came to me one summer night" (Mr. Moonlight)

**Dreams and Imagination**
Surreal and dreamlike imagery blending reality with fantasy.
- "From your beam you made my dream" (Mr. Moonlight)
- "Lives in a dream" (Eleanor Rigby)
- "Picture yourself in a boat on a river" (Lucy in the Sky with Diamonds)
- "Cellophane flowers of yellow and green" (Lucy in the Sky with Diamonds)
- "Climb in the back with your head in the clouds" (Lucy in the Sky with Diamonds)

**Travel and Movement**
Lyrics reflecting exploration, cultural experience, and nostalgia for places.
- "Oh, show me round your snow-peaked mountains way down south" (Back in the U.S.S.R.)
- "Take me to your daddy's farm" (Back in the U.S.S.R.)
- "Let me hear your balalaikas ringing out" (Back in the U.S.S.R.)
- "Can you take me back where I've been from?" (Cry Baby Cry)

# Motifs & Imagery

- **Love and Devotion:** "You know I love you," "I'll always be true"
- **Loss and Grief:** "She thinks of him," "And though he'll never come back"
- **Loneliness:** "Ah, look at all the lonely people," "Wearing a face that she keeps in a jar by the door"
- **Nature Elements:** "Sit beside a mountain stream," "Swaying daisies sing," "You came to me one summer night"
- **Dreamlike and Surreal Imagery:** "Picture yourself in a boat on a river," "Cellophane flowers of yellow and green," "Climb in the back with your head in the clouds"
- **Cultural and Geographic References:** "Snow-peaked mountains," "Balalaikas ringing out," "Daddy's farm"

# Caveats (Evidence Limits)
- No evidence was found regarding social commentary or political themes.
- Limited data on motifs related to time, change, or personal growth.
- The analysis does not cover lyrical or musical structures such as refrains or metaphors beyond thematic content.
- The evolution of themes across different Beatles albums or periods is not addressed due to the current scope of evidence.

LOGS:
[planner]
1. Find lyrics about love and relationships in Beatles songs.
2. Find lyrics about loneliness and emotional struggle in Beatles songs.
3. Find lyrics about nature and seasons in Beatles songs.
4. Find lyrics about dreams and imagination in Beatles songs.
5. Find lyrics about travel and movement in Beatles songs.
[researcher] extracted 26 evidence items
[analyst] analysis produced from evidence
[writer] draft produced from evidence
[reviewer_validator] validation pass completed
[reviewer_editor] edit pass completed
```

That's actually much better. Every claim in the final report is now traceable to evidence extracted from the corpus, and mistakes are no longer silently propagated. When the system confused lyrics from Baby's in Black with Julia, the validator detected the mismatch and removed the offending quotes rather than rationalising them away. This marks a clear shift from "trust the model" to "enforce the contract".

Also importantly, the system now fails conservatively. Themes without sufficient supporting evidence are omitted, and the report explicitly states what it cannot justify — such as political themes or long-term lyrical evolution. Instead of filling gaps with plausible-sounding language, the pipeline prefers absence over invention, ensuring that uncertainty is visible rather than disguised.

But there are still problems. Theme selection is still driven by the Planner rather than discovery, and the system has no notion of chronology or album structure. We'll come back to that.

## Conclusion

So we made some progress in ensuring correct output from the pipeline. What I have done:

- narrow what each agent is allowed to say,
- make failure visible,
- and prevent unsupported claims from propagating.

The system still fails — but now it fails in a controlled way.

---

## What comes next

In Part IV, I'll focus on retrieval itself.

Even with evidence gating, semantic search still misses exact lines and returns partial context. Next up is tightening retrieval quality and attribution — without pretending it's "solved".

That's where things get really interesting.
