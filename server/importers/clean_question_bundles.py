#!/usr/bin/env python3
"""
Clean Question Bundles

Applies text cleaning to existing question bundles to remove format-specific markers:
- Quiz Bowl: "For 10 points", "FTP", power markers (*)
- Science Bowl: W) X) Y) Z) answer prefixes

Usage:
    python3 clean_question_bundles.py [--input FILE] [--output FILE] [--verify]
"""

import argparse
import json
import re
from pathlib import Path
from typing import Any


# Quiz Bowl markers to remove from question text
QB_MARKERS = [
    r"\s*For\s+10\s+points?,?\s*",
    r"\s*For\s+ten\s+points?,?\s*",
    r"\s*FTP,?\s*",
    r"\s*\(\*\)\s*",  # Power marker
    r"\s*For\s+10\s+points?,?\s*name\s+",
    r"\s*For\s+10\s+points?,?\s*identify\s+",
    r"\s*For\s+10\s+points?,?\s*what\s+",
    r"\s*For\s+10\s+points?,?\s*who\s+",
    r"\s*For\s+10\s+points\s+each,?\s*",
]

# Science Bowl answer prefix pattern
SB_ANSWER_PREFIX = re.compile(r"^[WXYZ]\)\s*", re.IGNORECASE)


def clean_quiz_bowl_text(text: str) -> str:
    """Remove Quiz Bowl format markers from question text."""
    if not text:
        return text

    cleaned = text
    for pattern in QB_MARKERS:
        cleaned = re.sub(pattern, " ", cleaned, flags=re.IGNORECASE)

    # Clean up multiple spaces and trim
    cleaned = re.sub(r"\s+", " ", cleaned).strip()

    # Fix punctuation issues (space before punctuation)
    cleaned = re.sub(r"\s+([.,?!])", r"\1", cleaned)

    return cleaned


def clean_science_bowl_answer(answer: str) -> str:
    """Remove Science Bowl W/X/Y/Z prefixes from answers."""
    if not answer:
        return answer
    return SB_ANSWER_PREFIX.sub("", answer).strip()


def contains_qb_markers(text: str) -> bool:
    """Check if text contains any Quiz Bowl markers."""
    if not text:
        return False
    for pattern in QB_MARKERS:
        if re.search(pattern, text, re.IGNORECASE):
            return True
    return False


def clean_question(question: dict[str, Any]) -> dict[str, Any]:
    """Clean a single question's text and answers."""
    cleaned = question.copy()

    # Clean main text field
    if "text" in cleaned:
        cleaned["text"] = clean_quiz_bowl_text(cleaned["text"])

    # Clean content forms if present
    if "content" in cleaned and isinstance(cleaned["content"], dict):
        content = cleaned["content"].copy()
        # Keep pyramidalFull with markers for QB use
        # Clean mediumForm and shortForm for KB use
        if "mediumForm" in content:
            content["mediumForm"] = clean_quiz_bowl_text(content["mediumForm"])
        if "shortForm" in content:
            content["shortForm"] = clean_quiz_bowl_text(content["shortForm"])
        cleaned["content"] = content

    # Clean answer
    if "answer" in cleaned and isinstance(cleaned["answer"], dict):
        answer = cleaned["answer"].copy()

        # Clean primary answer
        if "primary" in answer:
            answer["primary"] = clean_science_bowl_answer(answer["primary"])

        # Clean acceptable answers
        if "acceptable" in answer and answer["acceptable"]:
            answer["acceptable"] = [
                clean_science_bowl_answer(a) for a in answer["acceptable"]
            ]

        cleaned["answer"] = answer

    return cleaned


def clean_bundle(bundle: dict[str, Any]) -> dict[str, Any]:
    """Clean all questions in a bundle."""
    cleaned = bundle.copy()

    if "questions" in cleaned:
        cleaned["questions"] = [
            clean_question(q) for q in cleaned["questions"]
        ]

    return cleaned


def count_markers(bundle: dict[str, Any]) -> dict[str, int]:
    """Count marker occurrences in a bundle."""
    stats = {
        "qb_markers_in_text": 0,
        "sb_prefixes_in_answers": 0,
        "total_questions": 0,
    }

    for q in bundle.get("questions", []):
        stats["total_questions"] += 1

        # Check text field
        text = q.get("text", "")
        if contains_qb_markers(text):
            stats["qb_markers_in_text"] += 1

        # Check content forms
        content = q.get("content", {})
        for form in ["mediumForm", "shortForm"]:
            if form in content and contains_qb_markers(content[form]):
                stats["qb_markers_in_text"] += 1

        # Check answers
        answer = q.get("answer", {})
        primary = answer.get("primary", "")
        if SB_ANSWER_PREFIX.match(primary):
            stats["sb_prefixes_in_answers"] += 1

        acceptable = answer.get("acceptable", []) or []
        for acc in acceptable:
            if SB_ANSWER_PREFIX.match(acc):
                stats["sb_prefixes_in_answers"] += 1

    return stats


def main():
    parser = argparse.ArgumentParser(
        description="Clean question bundles to remove format-specific markers"
    )
    parser.add_argument(
        "-i", "--input",
        type=Path,
        default=Path("output/kb-ios-bundle.json"),
        help="Input bundle file"
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        help="Output file (default: overwrites input with .cleaned suffix)"
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Only verify markers, don't clean"
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Overwrite input file"
    )
    parser.add_argument(
        "--sample-output",
        type=Path,
        help="Also write to iOS app sample questions location"
    )

    args = parser.parse_args()

    # Load bundle
    print(f"Loading {args.input}...")
    with open(args.input) as f:
        bundle = json.load(f)

    # Count markers before cleaning
    before_stats = count_markers(bundle)
    print(f"\n=== Before Cleaning ===")
    print(f"Total questions: {before_stats['total_questions']}")
    print(f"Questions with QB markers: {before_stats['qb_markers_in_text']}")
    print(f"Answers with SB prefixes: {before_stats['sb_prefixes_in_answers']}")

    if args.verify:
        return

    # Clean the bundle
    print("\nCleaning...")
    cleaned_bundle = clean_bundle(bundle)

    # Count markers after cleaning
    after_stats = count_markers(cleaned_bundle)
    print(f"\n=== After Cleaning ===")
    print(f"Total questions: {after_stats['total_questions']}")
    print(f"Questions with QB markers: {after_stats['qb_markers_in_text']}")
    print(f"Answers with SB prefixes: {after_stats['sb_prefixes_in_answers']}")

    # Determine output path
    if args.in_place:
        output_path = args.input
    elif args.output:
        output_path = args.output
    else:
        output_path = args.input.with_suffix(".cleaned.json")

    # Write cleaned bundle
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(cleaned_bundle, f, indent=2)
    print(f"\nWrote cleaned bundle to {output_path}")

    # Also write to sample output if specified
    if args.sample_output:
        args.sample_output.parent.mkdir(parents=True, exist_ok=True)
        with open(args.sample_output, "w") as f:
            json.dump(cleaned_bundle, f, indent=2)
        print(f"Wrote sample bundle to {args.sample_output}")


if __name__ == "__main__":
    main()
