# OpenCode tool output and attachments

## Universal truncation with full-output retrieval

Every tool result passes through one truncation stage before it reaches the
model. If the text exceeds the limits, OpenCode shows a bounded slice, writes the
**complete** output to a file, and appends a marker naming that file:

```text
[showing lines 1-N of M; full output saved to <global.data>/tool-output/tool_<id>]
```

- Defaults: `MAX_LINES = 2000`, `MAX_BYTES = 50 KiB`. Configurable via
  `tool_output.max_lines` / `tool_output.max_bytes`. This repo uses the defaults.
- The general tool path keeps the **head** (lines 1..N). The shell tool keeps the
  **tail** (the last N lines/bytes), since a command's outcome is usually at the
  end.
- On truncation the full output is still available on disk. Both paths use a
  **7-day retention** swept hourly:
  - **General tool output** is written to `<global.data>/tool-output/tool_<id>`
    and surfaced as `metadata.outputPath`.
  - **Shell output** is captured in `sh_<id>.out` and paged by `cursor`/`limit`;
    a consumer has more to read while `cursor < size`.
- Two caveats are specific to shell captures. The paging API only tracks live
  shells and the 25 most recent exited ones, so after a server restart — or once
  more than 25 shells have exited — a shell's ID is no longer pageable even
  though its capture file still exists on disk until the 7-day sweep removes it.
  The 25-shell eviction also unlinks a capture early. So the file is usually
  recoverable by path after a restart, but the convenient `cursor`/`limit` paging
  may not be.
- File-type content items (attachments) are never truncated; only text is.

The practical rule for workers: read the current output if it lets you do useful
work now, but do not loop re-reading a file waiting for more — page it
deliberately, or persist what must outlast the window. For shell evidence you
expect to reuse, record the capture file path (and read it promptly, since the
25-shell eviction can unlink it before the 7-day sweep).

## Attachments and media

Tool results carry attachments as `file` content items with a MIME type.

- **Images** are normalized and resized to a size limit. An image that cannot be
  resized under the limit, or cannot be decoded, is dropped and replaced with a
  note such as `[N images omitted: …]` rather than sent oversized. One exception:
  if the image resizer itself is unavailable (`Image.ResizerUnavailableError`),
  the original image item passes through unchanged, so size enforcement does not
  apply in that case.
- **PDFs and other media** pass through as file items; compaction estimates them
  for sizing only (image ≈ 1,500 tokens, PDF ≈ 2,000) and does not keep their
  bytes in a summary.
- In the compaction transcript, attachments are reduced to descriptors
  (`[Attached <mime>: <name>]`), not bytes (see
  `docs/opencode/15-compaction-context.md`).

## Large test logs and build output

`make check`, `go test`, and similar commands can exceed 50 KiB. The shell tool
keeps the tail (where failures and summaries appear) and saves the whole log to
the shell capture file. When a worker needs more than the tail — for example an
early compile error above the shown window — it pages the capture file rather
than re-running the command. Prefer narrowing the command (run one package,
filter output) over retrieving a huge log when the relevant part is known.

## Secret redaction: there is none

OpenCode does **not** redact secrets from tool output. Whatever a command prints
is shown to the model as-is and, when truncated, written verbatim to the
full-output file on disk. The P0 credential-rotation item (`points-chv`) exists
precisely because a tool printed an environment-derived API key in its `--help`
output, and nothing masked it.

Controls that do apply (area 2):

- Editing `.env`, `.env.*`, `.envrc`, `.envrc.local` is denied; reading `.env`
  patterns keeps OpenCode's built-in ask rules.
- Specialist prompts must not request environment dumps.
- `make check-dev` (not `make check`) runs `.bin/check-dev-config.sh`, which
  includes a secret-pattern scan. That scan covers a selected list of
  configuration and documentation paths, not every tracked file, so it is a
  backstop against committed secrets in those files — not a guarantee that no
  secret is committed anywhere.

What these controls do **not** cover: a secret that a legitimately-allowed
command emits into stdout/stderr. That output reaches the model and the
on-disk tool-output/shell-capture files unredacted. Treat command output as a
potential secret sink:

- Prefer commands that do not echo credentials (avoid `--help` on tools that
  interpolate env defaults, avoid `env`, `printenv`, and config dumps).
- If a secret does leak into output, rotate it (do not assume truncation hid it:
  the full value is on disk until retention sweeps it).
- Reviewers reading truncated evidence via `outputPath` see the unredacted file;
  keep those paths local and do not attach them to issues or PRs.

## Reviewer access to truncated evidence

A reviewer (human or an evaluator agent) that needs the evidence behind a
truncated result opens `metadata.outputPath` (general tools) or pages the shell
capture file. Because those files are unredacted and local, cite results in
Beads/PRs as summaries or specific quoted lines, never by attaching the raw
capture file.

## Decisions

- Keep the default tool-output limits (2000 lines / 50 KiB). They are large
  enough for normal `make check`/`go test` tails; raise `tool_output.max_bytes`
  only for a specific diagnostic need, not globally.
- Treat tool and shell output as an unredacted secret sink. Keep secrets out of
  commands rather than relying on OpenCode to mask them, and rotate any secret
  that reaches output.
- Retrieve full evidence by paging the saved capture/output file; do not re-run
  expensive commands to recover truncated detail, and do not publish capture
  file paths or contents outside the local machine.

## Runtime evidence

Confirmed from installed OpenCode v2.0.26 source the universal truncation stage
(`tool-output.ts`: 2000 lines / 50 KiB, head-kept, 7-day retention), the shell
tail truncation and cursor-paged capture file (`shell.ts`, `shell/result.ts`),
image normalization/omission (`tool.ts`), and the absence of any secret-redaction
pass in the tool or shell output paths. Confirmed neither the project nor the
global config overrides `tool_output`. No configuration change was made; this
area documents current behavior and the secret-sink caveat.
