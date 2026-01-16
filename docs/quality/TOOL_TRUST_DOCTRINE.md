# Tool Trust Doctrine

**All findings from established security and quality tools are presumed legitimate until proven otherwise through rigorous analysis.**

## The Core Principle

When CodeQL, SwiftLint, Ruff, Clippy, ESLint, or any established quality tool flags an issue, we:

1. **Assume it's real** - Not "might be real," assume it IS real
2. **Investigate deeply** - Full data flow analysis, not cursory review
3. **Fix the code** - The default outcome
4. **Adapt patterns** - If tools don't understand our code, our code should change
5. **Prove false positives** - Work quadruple hard to prove otherwise before dismissing

## Covered Tools

| Tool | Domain | Trust Level |
|------|--------|-------------|
| CodeQL | Security vulnerability scanning | High |
| SwiftLint | Swift code quality | High |
| Ruff/Pylint | Python code quality | High |
| Clippy | Rust code quality | High |
| ESLint | JavaScript/TypeScript quality | High |
| pip-audit | Python dependency vulnerabilities | High |
| npm audit | npm dependency vulnerabilities | High |
| Gitleaks | Secret detection | High |

New tools added to the CI/CD pipeline inherit this doctrine automatically.

## Process Flowchart

```
Tool flags an issue
        |
        v
Assume it's legitimate (DEFAULT)
        |
        v
Deep investigation (not cursory review)
        |
        v
    +-------+
    |       |
    v       v
Real issue?    Proven false positive?
    |               |
    v               v
Fix the code   Document WHY in detail
               Consider if pattern should change anyway
               Only then suppress (with audit trail)
```

## What "Proven False Positive" Requires

To dismiss a finding as a false positive, you MUST:

1. **Trace the full data flow** - Show exactly why the tool's concern doesn't apply
2. **Consider edge cases** - What if code is refactored? Copied elsewhere?
3. **Document the analysis** - Written explanation in PR or commit
4. **Get review** - Another set of eyes on the dismissal
5. **Question the pattern** - Even if safe, should we use a pattern tools understand?

**The bar for "false positive" is HIGH.** You must prove:
- The tool's concern doesn't apply AND
- Edge cases are covered AND
- Refactoring won't break safety AND
- The pattern couldn't reasonably be written in a tool-recognized way

## Anti-Patterns

| Wrong Approach | Why It's Wrong |
|----------------|----------------|
| "CodeQL doesn't understand our function" | Maybe our function pattern is the problem |
| "Create a custom config to suppress" | Blanket suppression hides future real issues |
| "Mark as false positive and move on" | Skips the learning opportunity |
| "Our code is correct, tool is wrong" | Arrogance that leads to vulnerabilities |
| "Add inline comment to silence warning" | Defeats the purpose of automated checks |

## Best Practices

### DO

- Investigate every finding thoroughly before dismissing
- Adapt code to use patterns tools recognize
- Document any suppressions with full justification
- Treat tool findings as learning opportunities
- Keep defense in depth even after refactoring

### DON'T

- Create custom configs to suppress findings as first response
- Use inline suppression comments without exhaustive analysis
- Assume your code is correct and the tool is wrong
- Dismiss findings without written documentation
- Suppress findings just to make CI pass

## Case Study: CodeQL Path Injection (January 2026)

### What Happened

CodeQL flagged 13 path injection vulnerabilities in our Python server code. Initial response was to create custom CodeQL configuration to mark our validation functions as trusted sanitizers.

### What Was Wrong

1. **We almost suppressed a real issue** - One finding (`handle_unarchive_curriculum`) had a genuine code pattern problem where original user input was used after validation instead of the validated result.

2. **Custom configs hide future issues** - Creating blanket suppressions would hide any future real vulnerabilities in the same pattern.

3. **We were adapting the tool to our code** - Instead of adapting our code to use patterns tools understand.

### The Fix

1. **Fixed the real vulnerability** - Changed `active_dir / file_name` to `active_dir / archived_path.name` to use the validated result

2. **Refactored validation function** - Changed `validate_path_in_directory()` to use CodeQL-recognized patterns (`Path.resolve()` + `str().startswith()`)

3. **Deleted custom configs** - Removed the CodeQL configuration files that were created in error

4. **Documented the lesson** - Created this doctrine to prevent future mistakes

### Key Takeaway

CodeQL was RIGHT. Even when we thought we understood our code better than the tool, investigation revealed a real issue. Trust the tools.

## Tool-Specific Patterns

### CodeQL Path Injection

CodeQL recognizes these patterns as safe:

```python
# Pattern 1: resolve() + startswith()
resolved = (base_dir / user_input).resolve()
if not str(resolved).startswith(str(base_dir.resolve()) + os.sep):
    raise ValueError("Path traversal")

# Pattern 2: os.path.normpath + startswith
fullpath = os.path.normpath(os.path.join(base, user_input))
if not fullpath.startswith(base):
    raise ValueError("Path traversal")

# Pattern 3: werkzeug secure_filename
from werkzeug.utils import secure_filename
safe_name = secure_filename(user_input)
```

CodeQL does NOT recognize custom validation functions, even if perfectly implemented.

### SwiftLint

SwiftLint rules are based on Swift community best practices. If SwiftLint flags something:

1. Check if it's a style issue vs logic issue
2. For style issues, follow the convention
3. For logic issues (force unwraps, etc.), fix the code
4. Only disable rules at project level with documented justification

### Clippy

Clippy represents Rust community expertise. When Clippy warns:

1. Read the lint documentation (Clippy explains WHY)
2. Most warnings have easy fixes
3. `#[allow(...)]` should be rare and documented
4. Consider if there's an idiomatic way to write the code

## Governance

### Adding New Tools

When adding a new quality tool to the CI/CD pipeline:

1. Add it to the "Covered Tools" table above
2. Document any project-specific configuration
3. The tool inherits the Tool Trust Doctrine automatically

### Requesting Exceptions

To request a permanent suppression:

1. Create a PR with the suppression
2. Include written analysis proving false positive
3. Document why the pattern can't be changed
4. Get review approval
5. Add entry to a suppressions audit log

### Audit

Periodically audit suppressions:

1. Review all inline suppression comments
2. Review all custom tool configurations
3. Verify each suppression still has valid justification
4. Remove suppressions where code has changed

## References

- [AGENTS.md](../../AGENTS.md) - Contains the mandatory Tool Trust Doctrine section
- [CLAUDE.md](../../CLAUDE.md) - AI agent instructions including tool trust
- [CodeQL Documentation](https://codeql.github.com/docs/)
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)
