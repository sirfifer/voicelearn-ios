#!/usr/bin/env python3
"""
Normalize Question Bundles

Fixes data quality issues in question bundles:
1. Normalizes answer types to valid schema values (text, multipleChoice, numeric)
2. Ensures acceptable answers array is never null
3. Optionally rebalances domain distribution

Usage:
    python3 normalize_question_bundles.py [--input FILE] [--output FILE] [--verify]
    python3 normalize_question_bundles.py --rebalance --target-size 1000
"""

import argparse
import json
import random
from collections import defaultdict
from pathlib import Path
from typing import Any, Optional


# Valid answer types per schema
VALID_ANSWER_TYPES = {"text", "multipleChoice", "numeric"}

# Mapping of invalid types to valid ones
ANSWER_TYPE_MAPPING = {
    "title": "text",
    "person": "text",
    "place": "text",
    "date": "text",
    "scientific": "text",
    "number": "numeric",
}

# Target domain distribution for Knowledge Bowl (percentages)
TARGET_DOMAIN_DISTRIBUTION = {
    "science": 0.20,
    "mathematics": 0.15,
    "literature": 0.12,
    "history": 0.12,
    "socialStudies": 0.10,
    "arts": 0.08,
    "currentEvents": 0.08,
    "language": 0.05,
    "technology": 0.04,
    "popCulture": 0.03,
    "religionPhilosophy": 0.02,
    "miscellaneous": 0.01,
}


def normalize_answer_type(answer_type: str) -> str:
    """Normalize an answer type to a valid schema value."""
    if answer_type in VALID_ANSWER_TYPES:
        return answer_type
    return ANSWER_TYPE_MAPPING.get(answer_type, "text")


def normalize_question(question: dict[str, Any]) -> dict[str, Any]:
    """Normalize a single question's answer structure."""
    normalized = question.copy()

    if "answer" in normalized and isinstance(normalized["answer"], dict):
        answer = normalized["answer"].copy()

        # Normalize answer type
        if "answerType" in answer:
            original_type = answer["answerType"]
            answer["answerType"] = normalize_answer_type(original_type)

        # Ensure acceptable is never null
        if answer.get("acceptable") is None:
            answer["acceptable"] = []

        normalized["answer"] = answer

    return normalized


def normalize_bundle(bundle: dict[str, Any]) -> dict[str, Any]:
    """Normalize all questions in a bundle."""
    normalized = bundle.copy()

    if "questions" in normalized:
        normalized["questions"] = [
            normalize_question(q) for q in normalized["questions"]
        ]

    return normalized


def count_answer_types(bundle: dict[str, Any]) -> dict[str, int]:
    """Count answer type distribution in a bundle."""
    types: dict[str, int] = defaultdict(int)

    for q in bundle.get("questions", []):
        answer = q.get("answer", {})
        answer_type = answer.get("answerType", "unknown")
        types[answer_type] += 1

    return dict(types)


def count_null_acceptables(bundle: dict[str, Any]) -> int:
    """Count questions with null acceptable answers."""
    count = 0
    for q in bundle.get("questions", []):
        answer = q.get("answer", {})
        if answer.get("acceptable") is None:
            count += 1
    return count


def count_domains(bundle: dict[str, Any]) -> dict[str, int]:
    """Count domain distribution in a bundle."""
    domains: dict[str, int] = defaultdict(int)

    for q in bundle.get("questions", []):
        domain = q.get("domain", "unknown")
        domains[domain] += 1

    return dict(domains)


def rebalance_bundle(
    bundle: dict[str, Any],
    target_size: int,
    seed: Optional[int] = None
) -> dict[str, Any]:
    """
    Rebalance a bundle to match target domain distribution.

    Uses stratified sampling to achieve target distribution while
    maximizing question variety.
    """
    if seed is not None:
        random.seed(seed)

    questions = bundle.get("questions", [])

    # Group questions by domain
    by_domain: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for q in questions:
        domain = q.get("domain", "miscellaneous")
        by_domain[domain].append(q)

    # Calculate target counts per domain
    target_counts: dict[str, int] = {}
    remaining = target_size

    for domain, percentage in sorted(
        TARGET_DOMAIN_DISTRIBUTION.items(),
        key=lambda x: x[1],
        reverse=True
    ):
        count = round(target_size * percentage)
        # Don't exceed available questions
        available = len(by_domain.get(domain, []))
        actual = min(count, available)
        target_counts[domain] = actual
        remaining -= actual

    # Distribute remaining slots to domains with excess questions
    if remaining > 0:
        for domain in sorted(
            by_domain.keys(),
            key=lambda d: len(by_domain[d]),
            reverse=True
        ):
            available = len(by_domain[domain])
            allocated = target_counts.get(domain, 0)
            extra = min(remaining, available - allocated)
            if extra > 0:
                target_counts[domain] = allocated + extra
                remaining -= extra
            if remaining <= 0:
                break

    # Sample questions from each domain
    rebalanced_questions: list[dict[str, Any]] = []

    for domain, count in target_counts.items():
        if count > 0 and domain in by_domain:
            available = by_domain[domain]
            if len(available) >= count:
                sampled = random.sample(available, count)
            else:
                sampled = available.copy()
            rebalanced_questions.extend(sampled)

    # Shuffle final list
    random.shuffle(rebalanced_questions)

    # Create new bundle
    rebalanced = bundle.copy()
    rebalanced["questions"] = rebalanced_questions
    rebalanced["metadata"] = rebalanced.get("metadata", {})
    rebalanced["metadata"]["rebalanced"] = True
    rebalanced["metadata"]["targetSize"] = target_size
    rebalanced["metadata"]["actualSize"] = len(rebalanced_questions)

    return rebalanced


def print_stats(bundle: dict[str, Any], label: str) -> None:
    """Print statistics for a bundle."""
    questions = bundle.get("questions", [])
    print(f"\n=== {label} ===")
    print(f"Total questions: {len(questions)}")

    # Answer types
    types = count_answer_types(bundle)
    print("\nAnswer Types:")
    for t, count in sorted(types.items(), key=lambda x: -x[1]):
        valid = "valid" if t in VALID_ANSWER_TYPES else "INVALID"
        print(f"  {t}: {count} ({valid})")

    # Null acceptables
    null_count = count_null_acceptables(bundle)
    print(f"\nNull acceptable arrays: {null_count}")

    # Domains
    domains = count_domains(bundle)
    print("\nDomain Distribution:")
    for d, count in sorted(domains.items(), key=lambda x: -x[1]):
        pct = count / len(questions) * 100 if questions else 0
        target = TARGET_DOMAIN_DISTRIBUTION.get(d, 0) * 100
        gap = pct - target
        indicator = "OK" if abs(gap) < 3 else ("HIGH" if gap > 0 else "LOW")
        print(f"  {d}: {count} ({pct:.1f}%) [target: {target:.0f}%] {indicator}")


def main():
    parser = argparse.ArgumentParser(
        description="Normalize question bundles to fix data quality issues"
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
        help="Output file (default: overwrites input with .normalized suffix)"
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Only verify issues, don't normalize"
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Overwrite input file"
    )
    parser.add_argument(
        "--rebalance",
        action="store_true",
        help="Rebalance domain distribution"
    )
    parser.add_argument(
        "--target-size",
        type=int,
        default=1000,
        help="Target bundle size when rebalancing (default: 1000)"
    )
    parser.add_argument(
        "--seed",
        type=int,
        help="Random seed for reproducible rebalancing"
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

    # Show before stats
    print_stats(bundle, "Before Normalization")

    if args.verify:
        return

    # Normalize the bundle
    print("\nNormalizing...")
    normalized_bundle = normalize_bundle(bundle)

    # Optionally rebalance
    if args.rebalance:
        print(f"\nRebalancing to target size {args.target_size}...")
        normalized_bundle = rebalance_bundle(
            normalized_bundle,
            args.target_size,
            args.seed
        )

    # Show after stats
    print_stats(normalized_bundle, "After Normalization")

    # Determine output path
    if args.in_place:
        output_path = args.input
    elif args.output:
        output_path = args.output
    else:
        output_path = args.input.with_suffix(".normalized.json")

    # Write normalized bundle
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(normalized_bundle, f, indent=2)
    print(f"\nWrote normalized bundle to {output_path}")

    # Also write to sample output if specified
    if args.sample_output:
        args.sample_output.parent.mkdir(parents=True, exist_ok=True)
        with open(args.sample_output, "w") as f:
            json.dump(normalized_bundle, f, indent=2)
        print(f"Wrote sample bundle to {args.sample_output}")


if __name__ == "__main__":
    main()
