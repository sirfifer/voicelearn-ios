"""
Text cleaning utilities for competition-specific markers.

Enables questions to be transformed cleanly between Quiz Bowl, Knowledge Bowl,
and Science Bowl formats. This is the Python equivalent of the Swift TextCleaner.
"""

import re
from typing import Optional


# Quiz Bowl point patterns
QB_POINT_PATTERNS = [
    # "For 10 points," "For ten points," "For 10 points, name"
    re.compile(r"[Ff]or\s+(?:10|ten|15|fifteen|20|twenty|5|five)\s+points?,?\s*", re.IGNORECASE),
    # "FTP," "FTP name"
    re.compile(r"FTP,?\s*", re.IGNORECASE),
    # Standalone point references at end of sentences
    re.compile(r",?\s*for\s+(?:10|ten|15|fifteen|20|twenty|5|five)\s+points?\.?\s*$", re.IGNORECASE),
]

# Quiz Bowl power marker
QB_POWER_MARKER = "(*)"

# Science Bowl answer prefix pattern: W), X), Y), Z)
SB_ANSWER_PREFIX_PATTERN = re.compile(r"^[WXYZ]\)\s*")


def clean_quiz_bowl_text(text: str) -> str:
    """
    Clean Quiz Bowl markers from question text.

    Removes:
    - "For 10 points," and variations
    - "FTP," abbreviation
    - (*) power markers
    - Trailing point references

    Args:
        text: Raw question text potentially containing QB markers

    Returns:
        Cleaned text suitable for Knowledge Bowl or general use
    """
    result = text

    # Remove power marker
    result = result.replace(QB_POWER_MARKER, "")

    # Remove point patterns using regex
    for pattern in QB_POINT_PATTERNS:
        result = pattern.sub("", result)

    # Clean up whitespace
    result = clean_whitespace(result)

    # Ensure proper sentence ending
    result = ensure_sentence_ending(result)

    return result


def clean_science_bowl_answer(answer: str) -> str:
    """
    Clean Science Bowl letter prefix from answer.

    Removes prefixes like "W) ", "X) ", "Y) ", "Z) " from answers.

    Args:
        answer: Raw answer potentially containing SB prefix

    Returns:
        Clean answer text
    """
    result = SB_ANSWER_PREFIX_PATTERN.sub("", answer)
    return result.strip()


def extract_science_bowl_letter(answer: str) -> Optional[str]:
    """
    Extract the letter from a Science Bowl answer prefix.

    Args:
        answer: Answer like "W) BASIC"

    Returns:
        The letter (e.g., "W") or None if no prefix
    """
    match = SB_ANSWER_PREFIX_PATTERN.match(answer)
    if match:
        return answer[0]
    return None


def extract_short_form(pyramidal: str) -> str:
    """
    Extract the last meaningful sentence from pyramidal text.

    Quiz Bowl pyramidal questions build up with clues, ending with the actual question.
    This extracts that final question portion for use in non-pyramidal formats.

    Args:
        pyramidal: Full pyramidal question text

    Returns:
        The final question sentence, cleaned of QB markers
    """
    # Clean QB markers first
    cleaned = clean_quiz_bowl_text(pyramidal)

    # Split into sentences
    sentences = split_into_sentences(cleaned)

    # Return the last sentence, or the whole thing if can't split
    if sentences:
        return sentences[-1]
    return cleaned


def extract_medium_form(pyramidal: str) -> str:
    """
    Extract a medium-length form from pyramidal text.

    Takes the last 2-3 sentences to provide more context than short_form
    while still being concise enough for Knowledge Bowl.

    Args:
        pyramidal: Full pyramidal question text

    Returns:
        The last 2-3 sentences, cleaned of QB markers
    """
    # Clean QB markers first
    cleaned = clean_quiz_bowl_text(pyramidal)

    # Split into sentences
    sentences = split_into_sentences(cleaned)

    # Take last 2-3 sentences depending on total length
    if len(sentences) >= 4:
        take_count = 3
    else:
        take_count = min(2, len(sentences))

    last_sentences = sentences[-take_count:] if sentences else [cleaned]
    return " ".join(last_sentences)


def contains_quiz_bowl_markers(text: str) -> bool:
    """
    Check if text contains Quiz Bowl markers.

    Useful for validation and quality checks.

    Args:
        text: Text to check

    Returns:
        True if QB markers are detected
    """
    # Check for power marker
    if QB_POWER_MARKER in text:
        return True

    # Check for point patterns
    for pattern in QB_POINT_PATTERNS:
        if pattern.search(text):
            return True

    return False


def contains_science_bowl_prefix(answer: str) -> bool:
    """
    Check if answer contains Science Bowl prefix.

    Args:
        answer: Answer to check

    Returns:
        True if SB prefix is detected
    """
    return bool(SB_ANSWER_PREFIX_PATTERN.match(answer))


def clean_whitespace(text: str) -> str:
    """Replace multiple spaces with single space."""
    return " ".join(text.split())


def ensure_sentence_ending(text: str) -> str:
    """Ensure text ends with proper punctuation."""
    text = text.strip()

    # If already ends with punctuation, return as-is
    if text and text[-1] in ".?!":
        return text

    # Add period if needed
    return text + "." if text else text


def split_into_sentences(text: str) -> list[str]:
    """
    Split text into sentences.

    Uses a simple approach that handles most common cases.

    Args:
        text: Text to split

    Returns:
        List of sentences
    """
    # Simple sentence splitting on . ? !
    # This is a simplified version - the Swift version uses linguistic analysis
    sentence_endings = re.compile(r"(?<=[.!?])\s+")
    sentences = sentence_endings.split(text)

    # Filter empty sentences and trim
    sentences = [s.strip() for s in sentences if s.strip()]

    return sentences


# Convenience functions for pipeline use


def clean_question_for_kb(text: str, answer: str, acceptable: list[str] | None = None) -> dict:
    """
    Clean a question for Knowledge Bowl format.

    Convenience function that cleans both text and answer.

    Args:
        text: Question text
        answer: Primary answer
        acceptable: List of acceptable alternative answers

    Returns:
        Dict with cleaned text, answer, and acceptable answers
    """
    cleaned_text = clean_quiz_bowl_text(text)
    cleaned_answer = clean_science_bowl_answer(answer)
    cleaned_acceptable = [clean_science_bowl_answer(a) for a in (acceptable or [])]

    return {
        "text": cleaned_text,
        "answer": cleaned_answer,
        "acceptable": cleaned_acceptable if cleaned_acceptable else None,
    }


def generate_text_forms(pyramidal_text: str) -> dict:
    """
    Generate all text forms from pyramidal Quiz Bowl text.

    Args:
        pyramidal_text: Full pyramidal question text with QB markers

    Returns:
        Dict with pyramidalFull, mediumForm, and shortForm
    """
    return {
        "pyramidalFull": pyramidal_text,  # Keep original for QB
        "mediumForm": extract_medium_form(pyramidal_text),  # Cleaned for KB
        "shortForm": extract_short_form(pyramidal_text),  # Cleaned, concise
    }
