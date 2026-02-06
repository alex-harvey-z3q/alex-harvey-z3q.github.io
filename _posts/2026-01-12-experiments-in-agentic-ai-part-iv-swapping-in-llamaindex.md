---
layout: post
title: "Experiments in Agentic AI, Part IV: Swapping in LlamaIndex"
date: 2026-01-12
author: Alex Harvey
tags: agentic-ai multi-agent rag
---

- ToC
{:toc}

## Introduction

This project was supposed to be about Agentic AI, although as things progressed, I came to realise that the retrieval layer is causing the real challenges, more so than any behaviour of the AI agents. Another goal of the project is to gain experience with as many technologies in use in industry in Agentic AI pipelines. So today, I've decided to replace LangChain - Chroma with [LlamaIndex](https://www.llamaindex.ai/).

## The problems

After various attempts to fix the retrieval I was still frequently experiencing hallucinated quotes, unsupported themes, a validator deleting entire sections, and agents contradicting each other — all leading to confident-sounding outputs that were not based on the facts.

But these weren’t reasoning failures; they were information failures.

A bit of researching led me to understand that I am not the only one, and many are turning away from LangChain to LlamaIndex to handle situations similar to mine.

This seemed like the perfect opportunity to learn about an emergingly popular tool like LlamaIndex.

So, I have refactored to use that.

## LlamaIndex

Skimming blog posts and marketing pages, LlamaIndex is said to be:

- a framework for connecting LLMs to your data
- a way to build powerful RAG applications
- a toolkit for agentic and multi-step reasoning over documents
- a higher-level abstraction that makes AI systems more intelligent

In short, the pitch is that LlamaIndex helps LLMs reason better by giving them better access to external data.

> LlamaIndex focuses on indexing, data ingestion and information retrieval from text-based data sources, making it ideal for simpler workflows and straightforward AI applications. Meanwhile, LangChain’s modular framework excels in the building of a wide range of natural language processing (NLP) and agentic AI applications.

LlamaIndex is gaining popularity because it makes retrieval-first architectures easier to build — especially once you’ve learned the hard way that retrieval is the hard part!

## Simpler workflow

After switching to LlamaIndex, I immediately have a better separation of concerns: a one-time indexing step that builds the retrieval structures and stores them in a gitignored directory. This avoids what I was doing before, namely re-deriving the retrieval structures every go at runtime.

(Note that the issue seems to be caused more by documentation that any real problem of features in LangChain. In LangChain + Chroma, all the code examples generally look like: load docs; split docs; embed docs — which normalises build on startup as a default. By contrast, LlamaIndex’s docs lead you to ingestion/indexing as a separate step.)

LlamaIndex is primarily designed for search and retrieval, turning large datasets into queryable structures.

> LlamaIndex equips LLMs with the capability of adding RAG functionality to the system using external knowledge sources, databases, and indexes as query engines for memory purposes.

## Implementing LlamaIndex

So here's what I did.

### Indexing as an explicit build step

Previously, my retrieval layer lived inside `tools.py` and could rebuild the vector store at runtime if it wasn’t already cached in memory. That meant the same code path could both answer questions and re-derive the index.

With LlamaIndex, indexing is now an explicit, one-off operation. I added a dedicated build script:

```
make index
```

Which runs:

```
python -m src.index_build
```

The build script parses the corpus, chunks it, embeds it, and persists the index to disk:

```python
# src/index_build.py

from llama_index.core import Settings, VectorStoreIndex, StorageContext
from llama_index.embeddings.openai import OpenAIEmbedding

Settings.embed_model = OpenAIEmbedding(model=EMBED_MODEL)

documents = load_beatles_lyrics_corpus(CORPUS_PATH)

index = VectorStoreIndex.from_documents(documents)

index.storage_context.persist(persist_dir=INDEX_PERSIST_DIR)
```

The resulting files are written to a local directory:

```
data/index_storage/
├── docstore.json
├── index_store.json
├── graph_store.json
├── default__vector_store.json
```

### Loading a prebuilt index at query time

At runtime, retrieval code now only loads an existing index.

The new `tools.py` contains a loader that reconnects to the persisted index:

```python
# src/tools.py

_index: Optional[VectorStoreIndex] = None

def _get_index() -> VectorStoreIndex:
    """
    Load and cache the persisted local LlamaIndex index.

    Prerequisite: run `python -m src.index_build` (or `make index`) once.
    """
    global _index

    if _index is not None:
        return _index

    # Ensure LlamaIndex is configured with the embedding model used at build time.
    Settings.embed_model = OpenAIEmbedding(model=EMBED_MODEL, api_key=OPENAI_API_KEY)

    storage_context = StorageContext.from_defaults(persist_dir=INDEX_PERSIST_DIR)
    _index = load_index_from_storage(storage_context)

    return _index
```

### Parsing the corpus as one document per song

Previously, document boundaries were implicit and relied on chunking behaviour.

With LlamaIndex, I made document boundaries explicit by parsing the corpus so that each song becomes a single document before chunking:

```python
# src/corpus.py

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

Chunking happens after this step, ensuring that all derived chunks inherit stable metadata.

This eliminated attribution errors where lyric fragments were detached from their source songs.

## Architecture: Before and After

A picture tells a thousand words and perhaps these diagrams make the changes to the architecture easier to understand. With LangChain we had a flow like this:

```
Song File
   │
   ▼
┌────────────────────────────┐
│ Document                   │
│ song=Yer Blues             │
│ album=The Beatles          │
│ source=Yer_Blues.txt       │
└────────────────────────────┘
               │
               ▼
┌────────────────────────────┐
│ TextSplitter               │
│                            │
│ ┌──────────────┐           │
│ │ Chunk A      │           │
│ │ "Yes I'm..." │           │
│ │ + metadata   │◄── copied │
│ ├──────────────┤           │
│ │ Chunk B      │           │
│ │ "Wanna die"  │           │
│ │ + metadata   │           │
│ └──────────────┘           │
└────────────────────────────┘
               │
               ▼
┌────────────────────────────┐
│ Vector Store (Chroma)      │
│                            │
│ - chunks stored            │
│ - no notion of document    │
│   boundary                 │
│ - metadata is flat         │
└────────────────────────────┘
               │
               ▼
┌────────────────────────────┐
│ Retrieval returns          │
│ chunks only                │
│                            │
│ Attribution relies on      │
│ metadata surviving         │
└────────────────────────────┘
```

The key point here is that after splitting, the system only knows about _chunks_.

Although each chunk carries a song field in its metadata, the system does not enforce any binding between the chunk's text and its attributed source, once retrieval begins. Chunks are selected by an AI embedding model based on semantic similarity, not on whether they contain the exact quoted line, and the model has no notion of "this text _must_ belong to this song." As a result, chunks that are thematically similar but originate from different songs can be retrieved and treated interchangeably, with metadata merely copied along for reference. When downstream AI agents then extract or paraphrase lyrics from this context, they may confidently attribute a line to the wrong song, because the relationship between text and source was never enforced—only assumed to remain correct.

In LlamaIndex however, the artictecture is different.

```
Song file block (beatles_lyrics.txt)
        │
        ▼
┌─────────────────────────────────────────┐
│ Document                                │
│ id: doc:yer_blues                       │
│ metadata:                               │
│   song="Yer Blues"                      │
│   album="TheBeatles"                    │
│   source_path="lyrics/TheBeatles/..."   │
└─────────────────────────────────────────┘
        │
        │  node parser / chunker
        ▼
┌────────────────────────────────────────────────────────────────┐
│ Node graph (stored in docstore / index)                        │
│                                                                │
│   ┌──────────────────────────┐                                 │
│   │ Document node            │                                 │
│   │ doc:yer_blues            │                                 │
│   └───────────┬──────────────┘                                 │
│               │ derived-into                                   │
│               │                                                │
│   ┌───────────┼───────────────────────────────┐                │
│   │           │                               │                │
│   ▼           ▼                               ▼                │
│ ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐|
│ │ TextNode        │   │ TextNode        │   │ TextNode        │|
│ │ node:abc123     │   │ node:def456     │   │ node:ghi789     │|
│ │ chunk 1 text    │   │ chunk 2 text    │   │ chunk 3 text    │|
│ │ metadata        │   │ metadata        │   │ metadata        │|
│ └───────┬─────────┘   └───────┬─────────┘   └───────┬─────────┘|
│         │                     │                     │          |
│         ▼                     ▼                     ▼          |
│                                                                │
└────────────────────────────────────────────────────────────────┘
        │
        │ retrieval
        ▼
┌─────────────────-───────────────────────┐
│ NodeWithScore                           │
│ node_id: node:abc123                    │
│ score: 0.87                             │
│ (node object + metadata intact)         │
└─────────────────────────────────────────┘
```


## Rerunning the pipeline

Now let's see what happens when we run it:

```

QUESTION:
What themes and lyrical motifs recur across The Beatles’ songs?

VALIDATED REPORT (input to editor):
## Issues removed
- Removed the quote "I will love her forever" (Every Little Thing) from the Love and Relationships section because it is not supported by the evidence (the evidence quotes "I'll Follow The Sun" for love/parting, not "Every Little Thing").
- Removed the quote "I'll follow the sun" (I'll Follow The Sun) from the Love and Relationships section because the evidence associates it with nature/weather/optimism and travel/movement, not explicitly love.
- Removed the quote "Pick up the bags, get in the limousine" (You Never Give Me Your Money) from the Love and Relationships section because it is supported only under travel/movement, not love.
- Removed the quote "I'm feeling blue and lonely" (What You're Doing) from the Loneliness and Emotional Struggle section because the evidence quotes "I'm feeling blue and lonely" but the song is "What You're Doing" (the evidence confirms this, so this is valid).
- Removed the quote "Sgt. Pepper's lonely" (Sgt Peppers Reprise) from the Loneliness and Emotional Struggle section because the evidence quotes "Sgt. Pepper's lonely" but the theme is loneliness/identity, which is a more specific theme than emotional struggle.
- Removed the quote "Well, they took some honey from a tree" (Everybodys Trying To Be My Baby) from the Nature and the Environment section because the evidence supports it as nature/environment/resource use, but the report states it evokes tranquility and optimism, which is not supported.
- Removed the motif "Loneliness and Isolation" example "I'm feeling blue and lonely" (What You're Doing) because the evidence supports it but the theme is emotional pain, not isolation.
- Removed the motif "Love and Affection" example "I will love her forever" (Every Little Thing) because the evidence does not support this quote.
- Removed the motif "Travel and Movement" example "I'll follow the sun" (I'll Follow The Sun) because the evidence supports it as travel/movement/hope but not as a motif example for travel and movement specifically.
- Removed the motif "Love and Affection" example "I will love her forever" (Every Little Thing) because the evidence does not support this quote.
- Removed the motif "Loneliness and Isolation" example "I'm feeling blue and lonely" (What You're Doing) because the evidence supports emotional pain but not isolation.
- Removed the motif "Nature Elements" example "tomorrow may rain, so I'll follow the sun" (I'll Follow The Sun) because the evidence supports it as nature/weather/optimism but the report overstates symbolism as peace and change.
- Removed the motif "Travel and Movement" example "I'll follow the sun" (I'll Follow The Sun) because the evidence supports it as travel/movement/hope but not as a motif example for travel and movement specifically.

## Validated report
# Executive summary
The Beatles’ lyrics consistently explore themes of love and relationships, loneliness and emotional struggle, nature and the environment, dreams and imagination, and travel and movement. These themes are supported by recurring motifs and imagery such as direct expressions of love, loneliness, natural elements like water and flowers, dream-related language, and symbols of travel like trains and bags. The evidence is drawn from a broad range of songs, illustrating the band’s lyrical diversity and emotional depth.

# Key themes

## Love and Relationships
The Beatles frequently address love in its many forms—affection, devotion, heartbreak, and universal love.
- "Darling, I love you" (Words Of Love)
- "All you need is love" (All You Need Is Love)
- "Though tonight she's made me sad, I still love her" (I Don't Want To Spoil The Party)
- "The love you take is equal to the love you make" (The End)
- "Remember that I'll always be in love with you" (PS I Love You)

## Loneliness and Emotional Struggle
Feelings of isolation, sadness, and self-doubt are prominent, sometimes touching on darker emotions.
- "Ah, look at all the lonely people" (Eleanor Rigby)
- "Yes, I'm lonely, Wanna die" (Yer Blues)
- "I'm a loser, And I'm not what I appear to be" (Im A Loser)
- "I'm feeling blue and lonely" (What You're Doing)
- "Though tonight she's made me sad" (I Don't Want To Spoil The Party)

## Nature and the Environment
Nature imagery evokes tranquility, optimism, and connection to the environment.
- "tomorrow may rain, so I'll follow the sun" (I'll Follow The Sun)
- "Sit beside a mountain stream" (Mother Nature's Son)
- "See her waters rise" (Mother Nature's Son)
- "Swaying daisies sing" (Mother Nature's Son)

## Dreams and Imagination
Dreams and imagination symbolize hope, love, and comfort.
- "from your beam you made my dream" (Mr. Moonlight)
- "One sweet dream came true" (You Never Give Me Your Money)
- "Dream sweet dreams for me" (Good Night)
- "Someday when we're dreaming" (Things We Said Today)

## Travel and Movement
Themes of travel and leaving convey urgency, change, and hope.
- "My baby says she's travelling on the one after 909" (One After 909)
- "Pick up my bags, run to the station" (One After 909)
- "One day you'll look to see I've gone" (I'll Follow The Sun)
- "I'll follow the sun" (I'll Follow The Sun)
- "Pick up the bags, get in the limousine" (You Never Give Me Your Money

FINAL REPORT (editor output):
## Issues removed
- Removed the quote "I will love her forever" (Every Little Thing) from the Love and Relationships section because it is not supported by the evidence (the evidence quotes "I'll Follow The Sun" for love/parting, not "Every Little Thing").
- Removed the quote "I'll follow the sun" (I'll Follow The Sun) from the Love and Relationships section because the evidence associates it with nature/weather/optimism and travel/movement, not explicitly love.
- Removed the quote "Pick up the bags, get in the limousine" (You Never Give Me Your Money) from the Love and Relationships section because it is supported only under travel/movement, not love.
- Removed the quote "I'm feeling blue and lonely" (What You're Doing) from the Loneliness and Emotional Struggle section because the evidence quotes "I'm feeling blue and lonely" but the song is "What You're Doing" (the evidence confirms this, so this is valid).
- Removed the quote "Sgt. Pepper's lonely" (Sgt Peppers Reprise) from the Loneliness and Emotional Struggle section because the evidence quotes "Sgt. Pepper's lonely" but the theme is loneliness/identity, which is a more specific theme than emotional struggle.
- Removed the quote "Well, they took some honey from a tree" (Everybodys Trying To Be My Baby) from the Nature and the Environment section because the evidence supports it as nature/environment/resource use, but the report states it evokes tranquility and optimism, which is not supported.
- Removed the motif "Loneliness and Isolation" example "I'm feeling blue and lonely" (What You're Doing) because the evidence supports it but the theme is emotional pain, not isolation.
- Removed the motif "Love and Affection" example "I will love her forever" (Every Little Thing) because the evidence does not support this quote.
- Removed the motif "Travel and Movement" example "I'll follow the sun" (I'll Follow The Sun) because the evidence supports it as travel/movement/hope but not as a motif example for travel and movement specifically.
- Removed the motif "Love and Affection" example "I will love her forever" (Every Little Thing) because the evidence does not support this quote.
- Removed the motif "Loneliness and Isolation" example "I'm feeling blue and lonely" (What You're Doing) because the evidence supports emotional pain but not isolation.
- Removed the motif "Nature Elements" example "tomorrow may rain, so I'll follow the sun" (I'll Follow The Sun) because the evidence supports it as nature/weather/optimism but the report overstates symbolism as peace and change.
- Removed the motif "Travel and Movement" example "I'll follow the sun" (I'll Follow The Sun) because the evidence supports it as travel/movement/hope but not as a motif example for travel and movement specifically.

## Validated report

# Executive Summary
The Beatles’ lyrics consistently explore themes of love and relationships, loneliness and emotional struggle, nature and the environment, dreams and imagination, and travel and movement. These themes are illustrated through recurring motifs and imagery such as direct expressions of love, feelings of loneliness, natural elements like water and flowers, dream-related language, and symbols of travel including trains and bags. The evidence spans a wide range of songs, highlighting the band’s lyrical diversity and emotional depth.

# Key Themes

## Love and Relationships
The Beatles frequently explore love in its many forms—affection, devotion, heartbreak, and universal love.
- "Darling, I love you" (Words Of Love)
- "All you need is love" (All You Need Is Love)
- "Though tonight she's made me sad, I still love her" (I Don't Want To Spoil The Party)
- "The love you take is equal to the love you make" (The End)
- "Remember that I'll always be in love with you" (PS I Love You)

## Loneliness and Emotional Struggle
Themes of isolation, sadness, and self-doubt are prominent, sometimes touching on darker emotions.
- "Ah, look at all the lonely people" (Eleanor Rigby)
- "Yes, I'm lonely, Wanna die" (Yer Blues)
- "I'm a loser, And I'm not what I appear to be" (Im A Loser)
- "I'm feeling blue and lonely" (What You're Doing)
- "Though tonight she's made me sad" (I Don't Want To Spoil The Party)

## Nature and the Environment
Nature imagery evokes a connection to the environment, often conveying tranquility and optimism.
- "tomorrow may rain, so I'll follow the sun" (I'll Follow The Sun)
- "Sit beside a mountain stream" (Mother Nature's Son)
- "See her waters rise" (Mother Nature's Son)
- "Swaying daisies sing" (Mother Nature's Son)

## Dreams and Imagination
Dreams and imagination symbolize hope, love, and comfort throughout the lyrics.
- "from your beam you made my dream" (Mr. Moonlight)
- "One sweet dream came true" (You Never Give Me Your Money)
- "Dream sweet dreams for me" (Good Night)
- "Someday when we're dreaming" (Things We Said Today)

## Travel and Movement
Themes of travel and departure convey urgency, change, and hope.
- "My baby says she's travelling on the one after 909" (One After 909)
- "Pick up my bags, run to the station" (One After 909)
- "One day you'll look to see I've gone" (I'll Follow The Sun)
- "I'll follow the sun" (I'll Follow The Sun)
- "Pick up the bags, get in the

LOGS:
[planner]
1. Find lyrics about love and relationships in Beatles songs.
2. Find lyrics about loneliness and emotional struggle in Beatles songs.
3. Find lyrics about nature and the environment in Beatles songs.
4. Find lyrics about dreams and imagination in Beatles songs.
5. Find lyrics about travel and movement in Beatles songs.
[researcher] extracted 28 evidence items
[analyst] analysis produced from evidence
[writer] draft produced from evidence
[reviewer_validator] validation pass completed
[reviewer_editor] edit pass completed
```

So that's actually an improvement. The LlamaIndex pipeline is now consistently surfacing verbatim lyric fragments that actually appear in the source material. Quotes like "Yes, I’m lonely, wanna die" (Yer Blues) and "Wearing a face that she keeps in a jar by the door" (Eleanor Rigby) are reliably present in the retrieved evidence, rather than being paraphrased or approximated by the model.

This matters because the downstream agents were already conservative. The validator aggressively removes unsupported claims, and the editor deletes entire sections when attribution looks shaky. In the earlier LangChain-based version, that conservatism often resulted in large portions of the report being stripped away. Here, the same agents are running unchanged — but they now have access to higher-quality evidence, so fewer sections need to be deleted.

Still, it's not perfect. Indeed, the results so far do not clearly demonstrate that multiple AI Agents have — so far — led to higher quality outcomes compared to what you'd expect just from ChatGPT 5.2 in instantaneous mode.

One issue that remains, for example, is ambiguity around theme boundaries. Many Beatles lyrics sit at the intersection of multiple themes, e.g. love, travel, optimism, or emotional change, and the system still struggles to draw clean lines between them. For example, lines like "I’ll follow the sun" has lyrics about movement, but the song is really simply a love song. So, the retrieval layer now reliably surfaces the correct lyrics, but the analyst agent stretches these lines into broad thematic claims.

We still then kind of end up with nonsense!

## Afterthoughts

Well I have had enough of this particular set up and in part V I am going to design a completely new stack to solve a new problem with new components. The goal is to learn and struggle with the same problems that engineers everywhere are struggling with in order to make AI Agents useful!

## References

- LlamaIndex vs LangChain: What's the difference? https://www.ibm.com/think/topics/llamaindex-vs-langchain

- LangChain vs LlamaIndex: A Detailed Comparison https://www.datacamp.com/blog/langchain-vs-llamaindex
