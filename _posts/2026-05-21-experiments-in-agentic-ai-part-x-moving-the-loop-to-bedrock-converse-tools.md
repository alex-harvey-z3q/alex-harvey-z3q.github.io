---
layout: post
title: "Experiments in Agentic AI, Part X: Moving the Loop to Bedrock Converse Tools"
date: 2026-05-21
author: Alex Harvey
tags: agentic-ai
---

- ToC
{:toc}

## Introduction

This post continues my experiment in building a minimal Claude Code-like coding agent on top of Amazon Bedrock. The project started as a RAG application, then gradually became a coding workflow with separate planner, implementer, and reviewer roles.

In [Part IX]({% post_url 2026-04-04-experiments-in-agentic-ai-part-ix-turning-a-one-pass-pipeline-into-a-claude-code-style-coding-loop %}), I turned that Planner -> Implementer -> Reviewer pipeline into a real coding loop. It could write files, run tests, review the result, feed failures back into the next iteration, and try again.

That was a useful step forwards. It meant the generated code was no longer just an answer in a chat transcript: It existed on disk, could be executed, could pass or fail unit tests, and could be reviewed against the actual files that had been written.

But there was still something awkward about it. Claude's interface to the workspace was not an interface in any real sense. It returned a large structured text response describing the files it wanted, and my Python code parsed that response, extracted file paths and content, wrote them into the workspace, ran tests, read files back from disk, and pasted the important parts into the next prompt.

In this post, I replace that prompt-shaped file exchange with [Amazon Bedrock Converse](https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_Converse.html) tool use. Claude can now request structured actions such as `write_file`, `read_file`, `list_files`, and `run_tests`; the application executes them against the workspace and returns the results.

## Workflow

```
                         OUTER WORKFLOW LOOP

   +-----------+
   |   Plan    |
   +-----+-----+
         |
         v
   +<----------------------------+--------------------------------+
   |                       Implement                              |
   |                                                              |
   |                 INNER BEDROCK TOOL LOOP                      |
   |                                                              |
   |   +--------------+      toolUse       +-----------------+    |
   |   | Claude via   | -----------------> | Python app      |    |
   |   | Bedrock      |                    | validates and   |    |
   |   | Converse     | <----------------- | executes tool   |    |
   |   +--------------+     toolResult     +--------+--------+    |
   |          ^                                     |             |
   |          |                                     v             |
   |          |                             +---------------+     |
   |          |                             | Workspace     |     |
   |          |                             | files/tests   |     |
   |          |                             +-------+-------+     |
   |          |                                     |             |
   |          +------- read/write/run results ------+             |
   |                                                              |
   +------------------------------+-------------------------------+
         ^                        |
         |                        v
         |               +----------------+
         |               | Run test gate  |
         |               +-------+--------+
         |                       |
         |                       v
         |               +----------------+
         |               | Review result  |
         |               +-------+--------+
         |                       |
         |                       v
         |               /----------------\
         |              /  Tests and       \
         |             /   review clean?    \
         |             \                    /
         |              \-------+------+---/
         |                      |      |
         |                   No |      | Yes
         |                      |      v
         |                      |   +--------+
         |                      |   | DONE   |
         |                      |   +--------+
         |                      |
         +------- feedback -----+
```

## The Code

The full code for this series is still here:

[https://github.com/alex-harvey-z3q/claude-code-minimal](https://github.com/alex-harvey-z3q/claude-code-minimal)

## Architecture

### Bedrock Converse

The key AWS service feature used in this version is Bedrock Converse. Converse is Bedrock's chat-style runtime API for multi-turn model interactions. Instead of calling a model with one prompt and receiving one text completion, the application sends a list of messages and receives the next assistant message.

For a simple chatbot, that might not sound very different from any other chat API. For this project, the important part is that Converse also has a tool-use protocol. The application can describe a set of tools in `toolConfig`; the model can respond with a structured `toolUse` request; the application can execute the corresponding local function; and the next Converse request can include a `toolResult` message containing the result.

This solution uses four parts of Converse:

- `messages`, to keep the conversation state across the implementer's work;
- `system`, to set the coding-agent role and rules;
- `inferenceConfig`, to set ordinary model parameters such as temperature and max tokens; and
- `toolConfig`, to tell Claude which structured tools it may request.

The tool-use part is the important change from the previous version. Bedrock is not running my tools. It is returning structured tool-use requests from Claude. My Python application receives those requests, decides whether they are valid, executes the corresponding local function, and sends the result back as a tool result.

In this architecture, Bedrock Converse is the protocol between Claude and my application. Claude decides that it wants to use a tool, Converse represents that request, and the application owns the side effect.

### Tool Use

The tools are deliberately small. Claude can list files, read files, write files, delete files, and run the generated unit tests. Those operations are enough to turn the implementer from a model that describes a patch into a model that can work against a real workspace.

Previously, Claude described the files it wanted my controller to write. Now, it can request a tool call against the workspace. The application validates the input, performs the action, captures the result, and decides when to stop.

That is the central shift. The workspace is no longer just external memory that gets pasted back into a later prompt. It has become the place where tool side effects happen.

This is also why the workspace boundary matters more now. The current version is not a hardened security sandbox. It prevents path traversal in the tool layer and keeps each run in its own directory, but tests still run as local subprocesses. For an experiment, that is enough to study the architecture. For arbitrary untrusted code, it would need a stronger isolation layer.

### The Inner and Outer Loops

Once the implementer can use tools, the diagram above ends up with two loops. This is the main architectural difference from Part IX.

The outer loop is the coding workflow I already had: plan, implement, run a test gate, review the result, and either stop or feed the failure back into another implementation attempt. That loop is still owned by the Python application. It decides whether an attempt passed tests and review.

The inner loop is the Bedrock tool loop inside the implementer. During a single implementation attempt, Claude can ask to call `write_file`, receive the result, ask to run tests, inspect a file, write another file, and continue. Each of those tool interactions is a tool round. It is not the same thing as an outer workflow iteration.

This surprised me. I now had two different meanings of "iteration":

- an outer workflow iteration, where the system decides whether the implementation passed tests and review, and
- an inner tool round, where the model asks for a tool, receives a result, and decides what to do next.

Most of the interesting debugging in this round came from the inner loop. In practice, the Minesweeper runs either succeeded inside that loop, with Claude writing files, running tests, fixing mistakes, and returning a completed attempt, or failed inside that loop before the outer workflow had anything useful to evaluate.

## Implementation Walkthrough

The implementation has three main pieces, and the easiest way to read them is in the order the workflow uses them:

- `api/src/api/agents.py` owns the coding workflow and calls the implementer.
- `api/src/api/sandbox.py` defines the workspace session, the tool schemas, and the Python handlers behind those tools.
- `api/src/api/llm.py` runs the Bedrock Converse loop that sends tool definitions to Claude, receives tool requests, executes handlers, and sends tool results back.

### `agents.py`

The outer workflow calls `implement_task()` from `agents.py`. That is the handoff from the workflow loop into the tool-using implementer:

```python
implement_output, implement_trace = implement_task(
    question,
    evidence,
    plan,
    sandbox,
    issue_summary=issue_summary,
    retry_mode=retry_mode,
)
```

The `sandbox` argument is important. The implementer is no longer returning a block of source files for the controller to parse. It is being given a workspace session that can expose tools.

The implementer prompt in `agents.py` now tells Claude to edit the workspace through tools instead of returning source files in its final answer:

```python
system_prompt = (
    "You are Implementer, a Python coding agent with access to a sandboxed "
    "workspace through tools. Create and edit files by calling tools; do not "
    "paste file contents into your final answer. "
    "Before you finish, run the tests with the run_tests tool. If tests fail, "
    "edit the workspace and run them again. Finish with a concise summary and "
    "never include full source files in the final response."
)
```

The hard requirements in the user prompt repeat the same rule more mechanically:

```python
"- use write_file/delete_file to change files\n"
"- every write_file call must include both path and content in the same tool input\n"
"- never call write_file with only a path; content must contain the complete file text\n"
"- use run_tests before finishing\n"
"- do not include source file bodies in your final text\n\n"
```

Those prompts matter because the old protocol trained the model to do the opposite: produce a big response containing all of the code. The new protocol asks it to mutate the workspace and leave the final response as a short summary.

After building the prompts, `implement_task()` asks the sandbox for tool specifications and handlers, then passes both into `invoke_claude_with_tools()`:

```python
tools, handlers = sandbox.tools(read_only=False)
response, tool_trace = invoke_claude_with_tools(
    system_prompt,
    user_prompt,
    tools=tools,
    handlers={name: _truncating_handler(handler) for name, handler in handlers.items()},
    max_tokens=4500,
    temperature=0.0,
)
```

This is where the architecture joins up. The tool specifications are for Bedrock and Claude. The handlers are for my application.

### `sandbox.py`

The tools themselves are defined by `SandboxSession.tools()` in `sandbox.py`. This method returns two things: the Bedrock tool specifications and the local Python handlers.

The current tool set is deliberately small:

| Tool | Available to implementer | Available to reviewer | Purpose |
|---|---|---|---|
| `list_files` | Yes | Yes | List files in the workspace so the model can orient itself. |
| `read_file` | Yes | Yes | Read a UTF-8 text file from the workspace. |
| `run_tests` | Yes | Yes | Run `unittest` discovery in the workspace and return the output. |
| `write_file` | Yes | No | Create or replace a UTF-8 text file in the workspace. |
| `delete_file` | Yes | No | Delete a file from the workspace. |

The reviewer gets the same inspection tools, but not the write tools. That keeps the reviewer in the role of judge rather than letting it mutate the candidate implementation.

The tool specification is what Claude sees. For example, `write_file` is described as a JSON-object tool with two required fields:

```python
{
    "toolSpec": {
        "name": "write_file",
        "description": (
            "Create or replace a UTF-8 text file in the sandbox workspace. "
            "The input must include both path and content in the same call."
        ),
        "inputSchema": {
            "json": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "content": {"type": "string"},
                },
                "required": ["path", "content"],
            }
        },
    }
}
```

The handler is the host-side function that actually does the write:

```python
handlers["write_file"] = self.write_file
```

And `write_file()` itself resolves the path inside the workspace before touching the filesystem:

```python
def write_file(self, path: str, content: str) -> str:
    file_path = self.resolve(path)
    if self._is_internal_path(file_path):
        raise ValueError(f"Refusing to write internal sandbox file: {path}")
    if file_path.suffix not in TEXT_SUFFIXES:
        raise ValueError(f"Refusing to write unsupported file type: {path}")
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content, encoding="utf-8")
    return f"Wrote {path} ({len(content)} characters)."
```

The path check is deliberately boring but important:

```python
def resolve(self, path: str = ".") -> Path:
    candidate = (self.root / path).resolve()
    if candidate != self.root and self.root not in candidate.parents:
        raise ValueError(f"Refusing to access path outside sandbox: {path}")
    return candidate
```

That is the workspace boundary. It is not a hardened security sandbox, but it means the tools are scoped to a per-run directory and cannot simply write `../../whatever`.

### `llm.py`

The Bedrock part is in `invoke_claude_with_tools()` in `llm.py`. At this point the workflow has a system prompt, user prompt, tool specifications, and handlers. The initial Converse call looks like a normal chat call, except that it also includes `toolConfig`:

```python
response = get_bedrock_client().converse(
    modelId=BEDROCK_CHAT_MODEL_ID,
    system=[{"text": system_prompt}],
    messages=messages,
    toolConfig={"tools": tools},
    inferenceConfig={
        "maxTokens": max_tokens,
        "temperature": temperature,
    },
)
```

The response may contain text, tool requests, or both. The tool requests arrive as `toolUse` blocks:

```python
output_message = response["output"]["message"]
messages.append(output_message)

content = output_message.get("content", [])
tool_uses = [part["toolUse"] for part in content if "toolUse" in part]
final_text_parts.extend(part.get("text", "") for part in content if "text" in part)

if not tool_uses:
    return "\n".join(part for part in final_text_parts if part).strip(), {
        "messages": messages,
        "tool_calls": tool_calls,
    }
```

No `toolUse` blocks means Claude has finished. Otherwise, the application loops over the requested tools, validates the JSON input, calls the matching handler, and records the result:

```python
for tool_use in tool_uses:
    name = tool_use["name"]
    tool_use_id = tool_use["toolUseId"]
    arguments = tool_use.get("input") or {}

    validation_error = _validate_tool_input(name, arguments, required_fields)
    if validation_error:
        result_text = validation_error
        status = "error"
    else:
        try:
            if name not in handlers:
                raise ValueError(f"Unknown tool: {name}")
            result_text = handlers[name](**arguments)
            status = "success"
        except Exception as exc:
            result_text = str(exc)
            status = "error"
```

The tool result is then appended as a new user message:

```python
result_content.append(
    {
        "toolResult": {
            "toolUseId": tool_use_id,
            "status": status,
            "content": [{"text": result_text}],
        }
    }
)

messages.append({"role": "user", "content": result_content})
```

That last step is the key to the inner loop. The application calls Converse again with the updated `messages` list. Claude sees the result of the tool it asked for, then decides whether to call another tool or finish with text.

There are also two guardrails that turned out to matter in practice. First, the code validates required fields from the tool schema before dispatching to the handler:

```python
missing = sorted(field for field in required_fields.get(name, set()) if field not in arguments)
```

Second, the loop has a hard limit:

```python
for _ in range(max_tool_rounds):
    ...

raise ToolLoopError(
    f"Claude did not finish after {max_tool_rounds} tool rounds.",
    provider=LLM_PROVIDER,
    model_id=BEDROCK_CHAT_MODEL_ID,
    max_tool_rounds=max_tool_rounds,
    tool_calls=tool_calls,
    partial_text=partial_text,
)
```

Without those checks, a bad tool-use pattern can become very opaque. In one of my test runs, Claude repeatedly called `write_file` with only a `path` and no `content`. The useful thing about having this loop in application code is that I could turn that into a traceable, bounded failure instead of letting it run indefinitely.

## Note about Claude Sonnet 4.6

It is important to note that earlier in this series I had been using Claude 3.5 Sonnet on Bedrock, mostly because it was the cheapest suitable Claude model available to me.

For this round, I was forced to upgrade to Claude Sonnet 4.6. When I tried to run the local workflow against the older configured model, Bedrock rejected the request because the model had been marked as `Legacy` and my account had not actively used it recently enough. The actual error I saw said I had not been actively using the model in the last 30 days.

This is part of Bedrock's model lifecycle behaviour: models can move from active, to legacy, and eventually to end-of-life. In practice, that meant the cheapest model I had been using earlier in the series was no longer callable for this experiment, so I moved to an active Sonnet 4.6 inference profile.

That means the Minesweeper results are not an apples-with-apples comparison against the previous post. The workflow is better, but the model is also better. So when the generated Minesweeper games improve, it is hard to say how much of that came from the Converse tool-use architecture and how much came from the Sonnet 4.6 upgrade.

## Running Locally with Bedrock

A separate but important refactor was making the agent runnable locally. The Converse tool loop still calls Bedrock for the model, but the API process, workspace, tool handlers, test runner, and trace files can now run on my MacBook without deploying ECS, RDS, S3, or the ALB.

That required separating the coding-agent path from the rest of the original RAG application. The coding loop can run without retrieval, but retrieval still depends on Postgres, pgvector, indexed data, and the embedding model. For local agent testing, I wanted to exercise the tool loop without also standing up that whole stack.

The local setup starts by creating a virtual environment and copying the example environment file:

```bash
cd claude-code-minimal
cd api
make venv
make install
cd ..
cp api/.env.example api/.env.local
```

For a real Bedrock run, `api/.env.local` needs to use the Bedrock provider:

```bash
LLM_PROVIDER=bedrock
AWS_REGION=ap-southeast-2
BEDROCK_CHAT_MODEL_ID=au.anthropic.claude-sonnet-4-6
DEFAULT_USE_RETRIEVAL=false
WORKSPACE_DIR=/tmp/claude-code-minimal-workspaces
MAX_WORKFLOW_ITERS=3
TEST_TIMEOUT_SECONDS=30
```

The important setting there is `DEFAULT_USE_RETRIEVAL=false`. The API now reads that value when deciding the default for `/query`, and the retrieval code is only imported when retrieval is actually requested. That means the local API can start without a database connection or a populated vector index.

There were a few other small pieces needed to make this work: safe local defaults for the database settings, lazy Bedrock imports, an `.env.local` path, and a `make dev-api` target. None of those are conceptually exciting, but they are the difference between "the code could work locally" and "I can actually start it from a terminal".

With that file in place, the local API starts with:

```bash
make dev-api
```

Under the hood, that runs `scripts/run_api_local.sh`, loads `api/.env.local`, sets `PYTHONPATH=src`, and starts Uvicorn on `127.0.0.1:8000`.

Before blaming the application for Bedrock failures, it is worth checking that local AWS credentials are available:

```bash
aws sts get-caller-identity
```

Then the basic local agent test is just an HTTP request to the API:

```bash
curl -sG 'http://127.0.0.1:8000/query' \
  --data-urlencode 'q=Build a tiny Python hello module with unittest tests.' \
  --data-urlencode 'use_retrieval=false'
```

The `use_retrieval=false` parameter is deliberate. It keeps this as a test of the coding workflow and tool loop, not a test of the RAG/database path.

The Sonnet 4.6 note above matters here because the model id in `api/.env.local` has to be one Bedrock will actually let the account call. Local mode removes the need to stand up my application infrastructure, but it does not remove the need for AWS credentials and Bedrock model access.

## Testing the Outer Loop

Once the inner tool loop was working, I wanted to check that I had not accidentally made the outer workflow loop irrelevant.

That was trickier than I first expected. My first instinct was to ask Claude to create a Minesweeper game with a deliberate bug and a test that caught it. The problem is that a tool-using model can notice the failing test, edit the file, run the tests again, and finish successfully without ever returning control to the outer workflow as a failed implementation attempt.

That is not bad behaviour from the model. In fact, it is exactly the kind of behaviour I want from the implementer. But it tests the inner tool loop, not the outer workflow loop.

To force the outer loop to do some work, I used a prompt that separated the first implementation attempt from the retry attempt:

```bash
curl -sG 'http://127.0.0.1:8000/query' \
  --data-urlencode 'q=Build a terminal Minesweeper game in Python with unittest tests. Keep it small but playable.

This is a test of the OUTER workflow retry loop, not a test of your ability to self-repair inside one tool loop.

First implementation attempt requirements:
- Deliberately introduce exactly one bug: make the win-condition logic incorrectly require all cells, including mines, to be revealed.
- Include a unittest that asserts the correct win condition: the player wins when all non-mine cells are revealed while mines remain hidden.
- Run the tests once.
- The expected result of the first implementation attempt is exactly one failing test caused by the deliberate win-condition bug.
- Do not fix that bug in the first implementation attempt. Returning with that single expected failure is the correct behavior for this attempt.

Retry attempt requirements:
- If you are given retry feedback about the win-condition failure, then fix the bug.
- After fixing it, run the tests and make them pass.' \
  --data-urlencode 'use_retrieval=false' \
  | tee /tmp/minesweeper-response.json \
  | python -m json.tool
```

The important line is the instruction not to fix the deliberate bug during the first attempt. Without that, Claude is quite likely to repair its own mistake inside the same tool loop, especially if it has already run the tests and seen the failure.

With that prompt, the system finally exercised the path I wanted to test:

1. The implementer created the game and tests.
2. The first attempt produced the expected failing test.
3. The outer workflow converted that failure into retry feedback.
4. The next implementation attempt fixed the win-condition bug.
5. The tests passed.

This was a useful reminder that there are now two kinds of success. If the model fixes its work before returning, the inner tool loop is succeeding. If the workflow observes a failed attempt, feeds back the failure, and gets a corrected implementation next time, the outer loop is succeeding.

Both behaviours are useful, but they are not the same thing.

## Making the Tool Loop Observable

Once I understood that distinction, the next problem was observability. The workflow already wrote an `agent_trace.json` file, but the trace was still too close to a dump of prompts and formatted tool calls. It was possible to debug a run by reading it carefully, but it was not easy to answer the basic questions:

- How many outer workflow iterations happened?
- How many inner tool rounds happened inside the implementer?
- Which tools were called, and how often?
- Did the implementer run tests once, or did it fail, edit, and run them again?
- Did any tool calls fail or arrive malformed?
- What did the reviewer inspect?

So I changed the trace shape. Each implementer and reviewer phase now records a compact `tool_loop` summary and a structured `tool_rounds` timeline. The top-level trace also gets an `observability` block that rolls those phase summaries up across the workflow.

For example, after another Minesweeper run, the top-level observability block looked like this:

```json
{
  "outer_iteration_count": 1,
  "total_tool_call_count": 21,
  "tool_call_counts": {
    "write_file": 10,
    "run_tests": 3,
    "list_files": 1,
    "read_file": 7
  },
  "phases": [
    {
      "phase": "implement",
      "round_count": 13,
      "tool_call_count": 13,
      "run_tests_count": 2,
      "error_count": 0
    },
    {
      "phase": "review",
      "round_count": 5,
      "tool_call_count": 8,
      "run_tests_count": 1,
      "error_count": 0
    }
  ],
  "stop_reason": "tests_passed_and_review_clean"
}
```

That is a much better debugging surface. It says immediately that the run completed in one outer workflow iteration, but the implementer still took 13 inner tool rounds and ran the tests twice.

The per-round trace then explains why:

```text
Round 1-8:  wrote the package, CLI, and tests
Round 9:    ran tests and hit one failing generated test
Round 10:   rewrote tests/test_game.py
Round 11:   reran tests and got 63 passing tests
Round 12:   listed files
Round 13:   returned the final summary
```

This is still not a polished trace viewer. I am still reading JSON with `jq`. But the important observability gap is mostly closed: the trace now has enough structure to show the outer workflow, the inner tool loop, test runs, failures, repairs, and final state without reconstructing the story by hand from a wall of text.

## Comparing the Successful Minesweeper Solutions

For release-candidate testing I kept asking the local agent to build the same small terminal Minesweeper game:

```text
Build a terminal Minesweeper game in Python with unittest tests. Keep it small but playable.
```

I ignored runs that failed before completion because of malformed tool calls or output limits. That left five successful first-outer-loop runs:

- `a70556757fa840bf9abee6d4c509c238`
- `9a770d5d0e76460d9e057fa943aced4f`
- `33daeaa128e94801ba3f99156df08c1b`
- `52ea90b4a21e411988196893afee6bc2`
- `46bd071b65254581ba8561e2b3d978cd`

All five completed in one outer workflow iteration, passed their generated unit tests, and produced a playable terminal game. That does not mean they were equally good. The observability work also made the table more interesting, because "one iteration" is no longer the only execution metric worth looking at.

| Run | Unit tests | Implementer tool calls | Implementer test runs | Inner-loop signal | Source LOC | Test LOC | Manual smoke | Notable finding |
|---|---:|---:|---:|---|---:|---:|---|---|
| `a7055675` | 61 passing | 11 | 1 | Green on first internal test run | 334 | 474 | Passed | Flood-fill could reveal a flagged safe cell; win check could be fooled after revealing mines |
| `9a770d5d` | 62 passing | 15 | 2 | Self-repaired after generated game-state tests failed | 341 | 472 | Passed | Best all-round result; fixed tests inside the tool loop and survived manual probes |
| `33daeaa1` | 44 passing | 14 | 2 | Self-repaired after a flagging/game-over test failed | 336 | 411 | Passed | Small custom boards could place too few mines and immediately win |
| `52ea90b4` | 60 passing | 14 | 2 | Self-repaired after a generated test accidentally revealed a win | 344 | 500 | Passed | Strong result, but direct `Board` API accepted out-of-bounds coordinates |
| `46bd071b` | 24 passing | 9 | 2 | Self-repaired the deliberately broken win condition inside the tool loop | 308 | 321 | Passed | Compact single-module design; interactive setup rather than CLI arguments |

The "implementer test runs" column is worth calling out. Only the first run wrote the implementation and got green tests immediately. The other four all hit at least one failing generated test, edited their own code or tests inside the Bedrock tool loop, and then returned with passing tests. (From the outer workflow's point of view, of course, those were still one-iteration successes.)

### Run `a7055675`

This implementation produced a clean package layout:

```text
main.py
minesweeper/
  __init__.py
  board.py
  display.py
  game.py
tests/
  __init__.py
  test_board.py
  test_display.py
  test_game.py
```

It wrote 61 passing unit tests and ran them successfully before finishing. The CLI also worked in a basic smoke test: I could flag a cell, reveal another cell, see the board update, and quit.

The manual review found two problems that the generated tests did not catch.

First, flood-fill did not consistently protect flagged cells. In a controlled board with a mine at `(4, 4)`, I flagged `(1, 1)` and revealed `(0, 0)`. The flag remained present, but the same cell was also revealed. That is an invalid state in Minesweeper.

Second, the win check used the number of revealed cells rather than the number of revealed non-mine cells. That means a board could be made to report a win after mines were revealed, because revealed mines counted toward the threshold.

So this run was playable and test-green, but not release-quality.

### Run `9a770d5d`

This run followed the same package shape but did more useful work inside the tool loop. Its first internal test run failed two generated tests around game state handling. Claude inspected the files, edited the implementation, ran the tests again, and finished with 62 passing tests.

The manual probes looked good:

- out-of-bounds `Board.reveal()` and `Board.flag()` raised `ValueError`;
- flagged cells survived flood-fill without being revealed;
- a `2x2` board with one mine placed exactly one mine after the first reveal;
- the CLI rendered a full board and accepted flag, reveal, and quit commands.

This was the strongest of the available runs. It is also the cleanest example of why the inner tool loop matters: the generated project was not correct on the first internal test run, but the implementer repaired it before the outer workflow had to retry.

### Run `33daeaa1`

This implementation used a slightly different internal model. Instead of storing board state in sets such as `mines`, `revealed`, and `flagged`, it represented each cell as a dictionary with keys like `mine`, `revealed`, `flagged`, and `adjacent`.

It generated 44 passing tests and a playable CLI. It also self-repaired once inside the tool loop: the first generated test run failed around flagging after game over, then Claude edited the code and returned with a green suite.

The interesting defect here was mine placement on very small boards. The implementation tried to keep the first clicked cell and all neighbours safe, but when that left too few candidate cells it sampled this:

```python
random.sample(candidates, min(self.num_mines, len(candidates)))
```

On a `2x2` board with one mine, the first-click safe zone covers the whole board. The candidate list is empty, so the game places zero mines and immediately reports a win after the first reveal.

That is not a problem for the default `9x9` game, but it is still a real correctness issue because the command-line interface allows custom board sizes.

### Run `52ea90b4`

This was another strong run. It generated 60 passing tests, rendered a proper board, handled CLI input correctly, preserved flags during flood-fill, and fixed the small-board mine-placement issue by falling back to excluding only the first clicked cell when the full safe zone was too large.

It also repaired itself inside the tool loop. The first generated test run failed because a "safe reveal returns playing" test accidentally revealed enough cells to win. Claude adjusted the test setup and finished with a passing suite.

The remaining issue was at the lower-level `Board` API. The `Game` controller validates coordinates before calling into the board, so the CLI path is protected. But calling `Board.reveal(-1, 0)` directly could place mines and add `(-1, 0)` to the revealed set, and `Board.flag(99, 99)` could store an invalid flag.

That makes it less polished than `9a770d5d`, but still a good generated implementation for normal gameplay.

### Run `46bd071b`

This run came from the deliberate outer-loop test prompt, so it is slightly different from the other four: the prompt explicitly asked for a win-condition bug on the first attempt and then allowed the retry attempt to fix it.

In practice, the model handled that inside one outer workflow iteration. The first internal test run failed two win-condition tests. Claude then read the implementation, fixed the win condition, and reran the suite. The final result had 24 passing tests.

The project shape was also more compact:

```text
main.py
minesweeper/
  __init__.py
  minesweeper.py
tests/
  __init__.py
  test_minesweeper.py
```

Manual smoke testing worked. The program prompted for rows, columns, and mine count, then accepted flag, reveal, and quit commands. The core probes also looked good:

- a `2x2` board with one mine placed exactly one mine after the first reveal;
- flagged cells survived flood-fill without being revealed;
- out-of-bounds reveal and flag calls returned `out_of_bounds`;
- the corrected win condition only required non-mine cells to be revealed.

The main drawback is interface polish. Unlike the later runs, this one does not accept `--rows`, `--cols`, and `--mines` command-line arguments. It prompts interactively instead. That still makes it playable, but it is less scriptable and less consistent with the other generated solutions.

### What the comparison showed

The main lesson from these runs is that "tests passed" is a useful signal, but not a complete release decision.

The generated test suites were not trivial. They ranged from 24 to 62 tests, covered multiple modules, and caught some bugs during the inner tool loop. But manual probes still found issues in three of the five successful runs.

The other lesson is that one outer iteration can hide quite a lot of inner activity. Four of the five successful runs failed at least one generated test internally and repaired themselves before returning. That is good news for the coding agent, but it means the outer workflow metric alone is too coarse. For this kind of system I want to track both:

- whether the outer workflow had to retry, and
- how much repair work happened inside the tool loop before the attempt finished.

The structured trace makes that second question much easier to answer. In the later observability run, for example, the top-level workflow still said "one iteration", but the trace showed 13 implementer rounds, two implementer test runs, one failing generated test, a rewrite of `tests/test_game.py`, and then a clean test run. That is exactly the kind of inner-loop story that the original trace made too hard to see.

## Lessons and Remaining Gaps

The biggest lesson is that tool use is a better abstraction than passing code around as formatted text.

In the previous version, the implementer had to emit files in a shape my controller could parse. Then the controller wrote those files, ran tests, read the workspace back, and fed selected contents into the next prompt. It worked, but the protocol was unnatural. The model was pretending to edit a workspace by printing the edits.

With Bedrock Converse tools, the model can ask to do the thing it actually needs to do: write a file, read a file, list the workspace, or run the tests. The application still controls the side effects, but the interaction is much closer to a real coding loop.

The second lesson is that tool use does not remove orchestration complexity. It moves it.

Once the model can request tools, the application needs to care about:

- the exact tool schema;
- validation of required fields;
- unknown tool names;
- path boundaries;
- output truncation;
- repeated malformed calls;
- maximum tool rounds;
- trace files that explain the run after the fact;
- and the cost of longer conversations.

The `write_file` failure made this concrete. Claude repeatedly tried to call `write_file` without `content`. That is a strange failure mode compared with the previous text-emission pipeline, but it is exactly the sort of failure a tool-using system has to handle. The fix was not just "prompt better". The application also needed to validate the tool input, return a useful error, count repeated malformed calls, and stop with a traceable failure.

The third lesson is that the outer workflow loop is still useful, but it is now a coarser signal than before. A run can complete in one outer iteration while still doing several rounds of edit-test-repair inside the implementer. That is a good thing, but it means that "completed in one iteration" is no longer enough detail. I also need to know how many tool rounds happened, how many tests were run, whether tests failed before passing, and what the model changed after seeing those failures.

Adding structured observability to `agent_trace.json` helped with that. The trace now records a top-level workflow summary, per-phase tool-loop summaries, and per-round tool timelines. That does not make it a full UI, but it does turn the inner loop from something I had to infer into something I can inspect directly.

The final lesson is about validation. Minesweeper is a small task, but it still exposed real differences between generated solutions. Passing 60 generated tests did not guarantee that a manual probe would find no bugs. Some defects were outside the generated test suite, and some were more about interface quality than pure correctness. That suggests a useful benchmark needs both automated checks and a small release-candidate review.

There are also obvious gaps.

The workspace boundary is useful, but it is not a hardened security boundary. Test execution still runs as a subprocess on the host, so a more serious version would need container or VM isolation, resource limits, and a clearer permission model.

The tool surface is still tiny. It is enough for this experiment, but real coding agents need richer filesystem operations, shell commands with permissions, search, patching, dependency installation, maybe browser or UI testing, and a way to ask before doing risky things.

The interface is also still just an API. There is no terminal-style UI, no streaming trace view, no approval prompts, and no ergonomic way to inspect the workspace while the model is working. The JSON trace is now much better, but it is still something I inspect after the fact rather than a live coding-agent interface. For this series that is fine, but it is another way in which this remains a minimal coding agent rather than a Claude Code replacement.

Finally, Minesweeper is probably too easy. It was useful because it exercised multi-file generation, tests, and manual play, but a better benchmark would involve an existing codebase, ambiguous requirements, dependencies, and changes that need to preserve prior behaviour.

## What Comes Next

The next useful step is to put a small UI on top of the trace data. The JSON trace now contains the right information, but reading it through `jq` is still a developer debugging workflow. A simple local trace viewer could show outer iterations, implement/review phases, inner tool rounds, failed test runs, repairs, and final state without making me spelunk through raw JSON.

After that, the execution boundary and tool surface need to grow together. Search, patching, shell commands, dependency installation, browser or UI testing, and stronger isolation are all obvious candidates, but they only make sense if they come with a permission model.

That is probably the real dividing line between this experiment and a usable local coding agent: once the agent can do more than edit files and run tests, it needs a way to ask before doing risky things.
