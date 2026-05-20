import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any


KEYWORDS = [
    "sbt",
    "ths",
    "animancer",
    "thsanimconponentanimancer",
    "thslowanimancerupdaterate",
    "thsanimancerdynamicupdaterate",
    "evaluate",
    "playable",
    "animator",
    "runtimeanimatorcontroller",
    "profiler.beginsample",
    "fanimtickrecord",
    "syncgroup",
    "blendspace",
    "unity",
    "unreal",
    "ue",
    "animation",
    "low update",
    "lowanim",
    "update rate",
]

PATH_RE = re.compile(
    r"(?i)([A-Z]:\\[^\s'\"`<>|]+|(?:[\w.-]+[\\/]){1,}[\w.-]+\.(?:cs|cpp|h|hpp|py|json|md|asset|prefab))"
)
SYMBOL_RE = re.compile(r"\b[A-Z_][A-Za-z0-9_]{3,}\b")
SECRET_RE = re.compile(
    r"(?i)(api[_-]?key|token|authorization|bearer|password|secret)\s*[:=]\s*['\"]?[^'\"\s,}]+"
)
KEYWORD_PATTERNS = {
    keyword: re.compile(rf"(?i)\b{re.escape(keyword)}\b")
    for keyword in ("sbt", "ths", "ue")
}


def redact(text: str) -> str:
    text = SECRET_RE.sub(r"\1=<REDACTED>", text)
    return text


def flatten_strings(value: Any, limit: int = 40) -> list[str]:
    found: list[str] = []

    def visit(node: Any) -> None:
        if len(found) >= limit:
            return
        if isinstance(node, str):
            if node.strip():
                found.append(node.strip())
            return
        if isinstance(node, dict):
            for item in node.values():
                visit(item)
                if len(found) >= limit:
                    return
            return
        if isinstance(node, list):
            for item in node:
                visit(item)
                if len(found) >= limit:
                    return

    visit(value)
    return found


def text_from_record(record: Any, role: str) -> str:
    """Extract useful dialogue text while avoiding large tool payloads."""
    if not isinstance(record, dict):
        return "\n".join(flatten_strings(record, limit=20))

    payload = record.get("payload")
    if not isinstance(payload, dict):
        payload = {}

    if role == "tool":
        candidates = [
            record.get("name"),
            record.get("tool_name"),
            payload.get("name"),
            payload.get("tool_name"),
            payload.get("method"),
        ]
        return "\n".join(str(item) for item in candidates if item)

    focused_fields = [
        record.get("content"),
        record.get("text"),
        record.get("message"),
        payload.get("content"),
        payload.get("text"),
        payload.get("message"),
    ]

    field_limit = 1000 if role == "user" else 30
    parts: list[str] = []
    for value in focused_fields:
        parts.extend(flatten_strings(value, limit=field_limit))

    if parts:
        return "\n".join(parts)

    return "\n".join(flatten_strings(record, limit=1000 if role == "user" else 40))


def role_of(record: dict[str, Any]) -> str:
    candidates = [
        record.get("role"),
        record.get("type"),
        record.get("event_type"),
        record.get("payload", {}).get("role") if isinstance(record.get("payload"), dict) else None,
        record.get("payload", {}).get("type") if isinstance(record.get("payload"), dict) else None,
    ]
    text = " ".join(str(x).lower() for x in candidates if x)
    if "user" in text:
        return "user"
    if "assistant" in text:
        return "assistant"
    if "tool" in text or "function" in text:
        return "tool"
    if "system" in text:
        return "system"
    return "event"


def score_text(text: str) -> tuple[int, list[str]]:
    lowered = text.lower()
    hits = []
    for kw in KEYWORDS:
        pattern = KEYWORD_PATTERNS.get(kw)
        if pattern:
            if pattern.search(text):
                hits.append(kw)
        elif kw in lowered:
            hits.append(kw)
    score = len(hits)
    score += min(8, len(PATH_RE.findall(text)))
    score += min(6, len(SYMBOL_RE.findall(text)) // 4)
    return score, hits


def normalize_text(text: str) -> str:
    text = redact(text).replace("\r\n", "\n").replace("\r", "\n")
    return re.sub(r"\n{3,}", "\n\n", text)


def compact(text: str, max_chars: int = 1800) -> str:
    text = normalize_text(text)
    if len(text) <= max_chars:
        return text
    head = text[: max_chars // 2].rstrip()
    tail = text[-max_chars // 2 :].lstrip()
    return f"{head}\n\n...[truncated]...\n\n{tail}"


def estimate_tokens(text: str) -> int:
    ascii_chars = 0
    cjk_chars = 0
    other_chars = 0
    for char in text:
        codepoint = ord(char)
        if codepoint < 128:
            ascii_chars += 1
        elif (
            0x4E00 <= codepoint <= 0x9FFF
            or 0x3400 <= codepoint <= 0x4DBF
            or 0xF900 <= codepoint <= 0xFAFF
        ):
            cjk_chars += 1
        else:
            other_chars += 1
    return max(1, int(ascii_chars / 4 + cjk_chars + other_chars / 2))


def record_token_estimate(record: dict[str, Any]) -> int:
    metadata = f"line={record['line']} role={record['role']} score={record['score']} hits={','.join(record['hits'])}"
    return estimate_tokens(metadata) + estimate_tokens(record["text"]) + 40


def write_records_markdown(path: Path, title: str, records: list[dict[str, Any]]) -> None:
    lines = [f"# {title}", ""]
    for idx, item in enumerate(records, start=1):
        hits = ", ".join(item["hits"])
        fence = "```"
        while fence in item["text"]:
            fence += "`"
        lines.extend(
            [
                f"## {idx}. line {item['line']} role={item['role']} score={item['score']}",
                "",
                f"Hits: {hits}",
                "",
                f"{fence}text",
                item["text"],
                fence,
                "",
            ]
        )
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--session", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--max-records", type=int, default=2000)
    parser.add_argument("--chunk-size", type=int, default=250, help="Maximum records per chunk.")
    parser.add_argument(
        "--max-chunk-tokens",
        type=int,
        default=30000,
        help="Maximum estimated tokens per chunk. Use 0 to disable token-based auto splitting.",
    )
    parser.add_argument(
        "--include-tools",
        action="store_true",
        help="Include compact tool record text. Default keeps only user/assistant dialogue and skips tools/events/system records.",
    )
    args = parser.parse_args()

    session = Path(args.session)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    chunk_size = max(1, args.chunk_size)
    max_chunk_tokens = max(0, args.max_chunk_tokens)
    chunk_dir = out / "chunks"
    chunk_dir.mkdir(parents=True, exist_ok=True)
    for old_chunk in chunk_dir.glob("chunk-*.md"):
        old_chunk.unlink()

    scored: list[dict[str, Any]] = []
    keyword_counts: Counter[str] = Counter()
    paths: Counter[str] = Counter()
    symbols: Counter[str] = Counter()
    roles: Counter[str] = Counter()
    skipped_tool_records = 0
    skipped_non_dialogue_records = 0
    total = 0
    parse_errors = 0

    with session.open("r", encoding="utf-8", errors="replace") as fh:
        for line_no, line in enumerate(fh, start=1):
            total += 1
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                parse_errors += 1
                record = {"raw": line}

            role = role_of(record) if isinstance(record, dict) else "event"
            roles[role] += 1
            if role == "tool" and not args.include_tools:
                skipped_tool_records += 1
                continue
            if role not in ("user", "assistant", "tool"):
                skipped_non_dialogue_records += 1
                continue
            text = text_from_record(record, role)
            if not text:
                continue
            score, hits = score_text(text)
            pinned_user = role == "user"
            if score <= 0 and not pinned_user:
                continue
            for hit in hits:
                keyword_counts[hit] += 1
            for match in PATH_RE.findall(text):
                paths[redact(match)] += 1
            for match in SYMBOL_RE.findall(text):
                if any(ch.islower() for ch in match) and len(match) >= 5:
                    symbols[match] += 1
            scored.append(
                {
                    "line": line_no,
                    "role": role,
                    "score": score,
                    "hits": sorted(set(hits)),
                    "pinned_user": pinned_user,
                    "text": normalize_text(text) if pinned_user else compact(text),
                }
            )

    ranked = sorted(scored, key=lambda item: (item["score"], len(item["hits"])), reverse=True)
    for rank, item in enumerate(ranked, start=1):
        item["rank"] = rank
    pinned_users = [item for item in scored if item.get("pinned_user")]
    pinned_lines = {item["line"] for item in pinned_users}
    remaining_slots = max(0, args.max_records - len(pinned_users))
    selected = sorted(
        pinned_users + [item for item in ranked if item["line"] not in pinned_lines][:remaining_slots],
        key=lambda item: item["line"],
    )
    preview = ranked[: min(200, len(ranked))]
    matched_records = sum(1 for item in scored if item["score"] > 0)
    selected_user_records = sum(1 for item in selected if item["role"] == "user")
    selected_non_user_records = len(selected) - selected_user_records

    chunks: list[dict[str, Any]] = []
    pending_chunk: list[dict[str, Any]] = []
    pending_tokens = 0

    def flush_chunk() -> None:
        nonlocal pending_chunk, pending_tokens
        if not pending_chunk:
            return
        chunk_index = len(chunks) + 1
        chunk_name = f"chunk-{chunk_index:03d}.md"
        chunk_path = chunk_dir / chunk_name
        first_line = pending_chunk[0]["line"]
        last_line = pending_chunk[-1]["line"]
        write_records_markdown(
            chunk_path,
            f"SBT Animancer Evidence Chunk {chunk_index:03d}",
            pending_chunk,
        )
        chunks.append(
            {
                "index": chunk_index,
                "file": f"chunks/{chunk_name}",
                "record_count": len(pending_chunk),
                "estimated_tokens": pending_tokens,
                "first_line": first_line,
                "last_line": last_line,
            }
        )
        pending_chunk = []
        pending_tokens = 0

    for item in selected:
        item_tokens = record_token_estimate(item)
        item["estimated_tokens"] = item_tokens
        would_exceed_count = len(pending_chunk) >= chunk_size
        would_exceed_tokens = (
            max_chunk_tokens > 0
            and pending_chunk
            and pending_tokens + item_tokens > max_chunk_tokens
        )
        if would_exceed_count or would_exceed_tokens:
            flush_chunk()
        pending_chunk.append(item)
        pending_tokens += item_tokens
    flush_chunk()

    manifest = {
        "session": str(session),
        "session_size_bytes": session.stat().st_size,
        "total_jsonl_lines": total,
        "parse_errors": parse_errors,
        "matched_records": matched_records,
        "candidate_records": len(scored),
        "selected_records": len(selected),
        "selected_user_records": selected_user_records,
        "selected_non_user_records": selected_non_user_records,
        "pinned_user_records": len(pinned_users),
        "selected_records_exceed_max": len(selected) > args.max_records,
        "max_records": args.max_records,
        "chunk_size": chunk_size,
        "max_chunk_tokens": max_chunk_tokens,
        "chunk_count": len(chunks),
        "chunks": chunks,
        "roles": dict(roles),
        "include_tools": args.include_tools,
        "allowed_roles": ["user", "assistant"] + (["tool"] if args.include_tools else []),
        "skipped_tool_records": skipped_tool_records,
        "skipped_non_dialogue_records": skipped_non_dialogue_records,
        "keyword_counts": dict(keyword_counts.most_common()),
    }
    (out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    with (out / "evidence.jsonl").open("w", encoding="utf-8", newline="\n") as fh:
        for item in selected:
            fh.write(json.dumps(item, ensure_ascii=False) + "\n")

    summary_lines = [
        "# SBT Animancer Session Evidence Summary",
        "",
        f"- Session: `{session}`",
        f"- Size bytes: `{manifest['session_size_bytes']}`",
        f"- Total JSONL lines: `{total}`",
        f"- Parse errors: `{parse_errors}`",
        f"- Matched records: `{matched_records}`",
        f"- Candidate records: `{len(scored)}`",
        f"- Selected records: `{len(selected)}`",
        f"- Selected user records: `{selected_user_records}`",
        f"- Selected non-user records: `{selected_non_user_records}`",
        f"- Pinned user records: `{len(pinned_users)}`",
        f"- Max records: `{args.max_records}`",
        f"- Chunk size: `{chunk_size}` records max",
        f"- Max chunk tokens: `{max_chunk_tokens}` estimated tokens",
        f"- Chunk count: `{len(chunks)}`",
        f"- Evidence mode: `{'user/assistant/tool' if args.include_tools else 'user/assistant only'}`",
        f"- Include tool records: `{args.include_tools}`",
        f"- Skipped tool records: `{skipped_tool_records}`",
        f"- Skipped non-dialogue records: `{skipped_non_dialogue_records}`",
        "",
        "## Keyword Counts",
        "",
    ]
    for key, count in keyword_counts.most_common(80):
        summary_lines.append(f"- `{key}`: {count}")
    summary_lines.extend(["", "## Roles", ""])
    for key, count in roles.most_common():
        summary_lines.append(f"- `{key}`: {count}")
    summary_lines.extend(["", "## Chunks", ""])
    for chunk in chunks:
        summary_lines.append(
            f"- `{chunk['file']}`: {chunk['record_count']} records, ~{chunk['estimated_tokens']} tokens, lines {chunk['first_line']}-{chunk['last_line']}"
        )
    (out / "evidence_summary.md").write_text("\n".join(summary_lines) + "\n", encoding="utf-8")

    write_records_markdown(out / "relevant_records.md", "Top Relevant Records Preview", preview)

    file_lines = ["# File And Symbol Evidence", "", "## Paths", ""]
    for path, count in paths.most_common(200):
        file_lines.append(f"- `{path}`: {count}")
    file_lines.extend(["", "## Symbols", ""])
    for symbol, count in symbols.most_common(200):
        file_lines.append(f"- `{symbol}`: {count}")
    (out / "file_and_symbol_evidence.md").write_text("\n".join(file_lines) + "\n", encoding="utf-8")

    print(f"Wrote evidence package to {out}")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
