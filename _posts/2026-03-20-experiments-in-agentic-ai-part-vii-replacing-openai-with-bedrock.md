---
layout: post
title: "Experiments in Agentic AI, Part VII: Replacing OpenAI with Bedrock"
date: 2026-03-20
author: Alex Harvey
tags: agentic-ai rag
---

- ToC
{:toc}

## Introduction

In the previous post, I rebuilt the RAG pipeline on Azure, demonstrating that the core architecture — ingestion, indexing, and retrieval — is portable across cloud providers. The same containers, database, and application code could be reused with only modest changes to the infrastructure layer.

One dependency, however, remained constant up to this point: OpenAI.

In this post, I replace that remaining dependency with a fully AWS-native model layer using Amazon Bedrock. This change also aligns with a broader industry trend, where enterprises are increasingly adopting Bedrock to integrate foundation models within existing AWS environments.

With that in mind, I return to the original AWS pipeline (i.e. the state at the end of Part V) and make the minimal changes required to replace OpenAI with Bedrock, keeping the rest of the pipeline unchanged.

---

## Swapping the Model Layer

At a high level, the change looks like this:

```
                       RAG Pipeline
───────────────────────────────────────────────────────────

Wikipedia
   │
   ▼
Ingest Job
   │
   ▼
Object Storage (S3 / Blob → S3)
   │
   ▼
Indexer
   │
   ├── Embeddings ───────────────▶ OpenAI
   │                               ↓
   │                               Amazon Bedrock (Titan)
   │
   ▼
PostgreSQL + pgvector
   │
   ▼
FastAPI Retrieval API
   │
   ├── Query Embedding ──────────▶ OpenAI
   │                               ↓
   │                               Amazon Bedrock (Titan)
   │
   └── Answer Generation ────────▶ ChatGPT / Azure OpenAI
                                   ↓
                                   Amazon Bedrock (Claude)
```

---

## The Code

As always, the full code for the system in this post is available at my GitHub:

[https://github.com/alex-harvey-z3q/wiki-rag-bedrock](https://github.com/alex-harvey-z3q/wiki-rag-bedrock)

---

## Setting up Amazon Bedrock

Before models can be invoked via Amazon Bedrock, two pieces of configuration are required: enabling model access (a manual step), and granting the correct IAM permissions.

### Model access and use case submission

Access to Bedrock models is not enabled by default. For Anthropic models, AWS requires submission of a short use case form before access is granted. Navigate to **Amazon Bedrock → Model catalog** and request access to the required models.

For this project, I used:

- **Anthropic Claude 3.5 Sonnet** (answer generation)
- **Amazon Titan embeddings** (vector embeddings)

### IAM permissions

In addition, the application (in ECS) needs to be granted permissions to invoke the model:

```json
{
  "Effect": "Allow",
  "Action": [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream"
  ],
  "Resource": "*"
}
```

As well as AWS Marketplace permissions:

```json
{
  "Effect": "Allow",
  "Action": [
    "aws-marketplace:Subscribe",
    "aws-marketplace:ViewSubscriptions",
    "aws-marketplace:Unsubscribe"
  ],
  "Resource": "*"
}
```

Once these permissions are in place, the application can invoke Bedrock models using its IAM role, without requiring any API keys.

---

## Consuming Bedrock in code

Once Bedrock access and IAM permissions are in place, the application changes are fairly localised. In practice, consuming Bedrock requires three things:

1. configuring the Bedrock model IDs
2. using Bedrock embeddings for retrieval
3. using the Bedrock runtime client to call Claude for answer generation

### Configuration

The first step was to replace the old provider-oriented configuration with a small Bedrock-specific settings module:

```python
import os

AWS_REGION = "ap-southeast-2"

BEDROCK_CHAT_MODEL_ID = "anthropic.claude-3-5-sonnet-20241022-v2:0"
BEDROCK_EMBED_MODEL_ID = "amazon.titan-embed-text-v2:0"

DB_HOST = os.environ["DB_HOST"]
DB_PORT = 5432
DB_NAME = "postgres"
DB_USER = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]

PGVECTOR_SCHEMA = "public"
PGVECTOR_TABLE = "data_wiki_rag_nodes"
EMBED_DIM = int(os.environ["EMBED_DIM"])

TOP_K = 5
TEMPERATURE = 0.2
MAX_TOKENS = 512
```

### Query embeddings with Titan

On the retrieval side, the API now uses `BedrockEmbedding` from LlamaIndex to embed incoming queries:

```python
from functools import lru_cache

from llama_index.core import Settings, VectorStoreIndex
from llama_index.core.base.base_retriever import BaseRetriever
from llama_index.embeddings.bedrock import BedrockEmbedding
from llama_index.vector_stores.postgres import PGVectorStore

from . import config


@lru_cache(maxsize=1)
def get_embedding_model() -> BedrockEmbedding:
    return BedrockEmbedding(
        model_name=config.BEDROCK_EMBED_MODEL_ID,
        region_name=config.AWS_REGION,
    )


@lru_cache(maxsize=1)
def get_vector_store() -> PGVectorStore:
    return PGVectorStore.from_params(
        host=config.DB_HOST,
        port=config.DB_PORT,
        database=config.DB_NAME,
        user=config.DB_USER,
        password=config.DB_PASSWORD,
        table_name=config.PGVECTOR_TABLE,
        schema_name=config.PGVECTOR_SCHEMA,
        embed_dim=config.EMBED_DIM,
    )


@lru_cache(maxsize=1)
def get_retriever() -> BaseRetriever:
    embed_model = get_embedding_model()
    Settings.embed_model = embed_model

    vector_store = get_vector_store()
    index = VectorStoreIndex.from_vector_store(
        vector_store=vector_store,
        embed_model=embed_model,
    )
    return index.as_retriever(similarity_top_k=config.TOP_K)
```

### Calling Claude via Bedrock

For answer generation, the OpenAI chat completion call was replaced with a Bedrock runtime client and a `converse(...)` request:

```python
from functools import lru_cache
from typing import Any, Mapping

import boto3

from .config import AWS_REGION, BEDROCK_CHAT_MODEL_ID, MAX_TOKENS, TEMPERATURE


@lru_cache(maxsize=1)
def get_bedrock_client():
    return boto3.client("bedrock-runtime", region_name=AWS_REGION)


def answer_with_evidence(
    question: str,
    evidence_items: list[Mapping[str, Any]],
) -> str:
    evidence_block = "\n\n".join(
        f"[{i+1}] {item['page']} — {item['section']}\n"
        f"URL: {item['url']}\n"
        f"Excerpt: {item['excerpt']}"
        for i, item in enumerate(evidence_items)
    )

    system_prompt = (
        "You are a careful assistant answering questions using ONLY the provided "
        "evidence excerpts from Wikipedia. If the evidence is insufficient, say "
        "you do not know. Always cite evidence items like [1], [2]."
    )

    user_prompt = f"Question: {question}\n\nEvidence:\n{evidence_block}"

    response = get_bedrock_client().converse(
        modelId=BEDROCK_CHAT_MODEL_ID,
        system=[{"text": system_prompt}],
        messages=[
            {
                "role": "user",
                "content": [{"text": user_prompt}],
            }
        ],
        inferenceConfig={
            "maxTokens": MAX_TOKENS,
            "temperature": TEMPERATURE,
        },
    )

    content = response["output"]["message"]["content"]
    text_parts = [part.get("text", "") for part in content if "text" in part]
    return "\n".join(part for part in text_parts if part).strip()
```

### The API endpoint

The FastAPI layer remained almost unchanged:

```python
from fastapi import FastAPI, Query

from .llm import answer_with_evidence
from .models import AskResponse
from .retrieval import retrieve

app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/query", response_model=AskResponse)
def query(q: str = Query(..., min_length=1, max_length=2000)):
    evidence = retrieve(q)
    answer = answer_with_evidence(q, evidence)
    return {"answer": answer, "evidence": evidence}
```

### The indexer

The indexing side was similarly reduced to a Bedrock-only embedding path:

```python
from llama_index.embeddings.bedrock import BedrockEmbedding

from indexer import settings


def get_embedding_model() -> BedrockEmbedding:
    return BedrockEmbedding(
        model_name=settings.BEDROCK_EMBED_MODEL_ID,
        region_name=settings.AWS_REGION,
    )
```

and then:

```python
from llama_index.core import Settings

from indexer.providers import get_embedding_model


def configure_embeddings() -> BedrockEmbedding:
    embed_model = get_embedding_model()
    Settings.embed_model = embed_model
    return embed_model
```

---

## Conclusion

With Bedrock in place, the pipeline now runs entirely within AWS, from ingestion through to answer generation. The model layer is no longer an external dependency, and access is managed through IAM alongside the rest of the system.

From a code perspective, the changes were minimal — embedding and generation calls were swapped out, while the overall RAG architecture remained unchanged.

In the next part of the series, I’ll build on this same pipeline to explore more agent-like behaviour on top of it.
