---
name: worktree
description: Manage git worktrees for parallel Claude Code development sessions
---

# /worktree - Parallel Development Management

## Purpose

Manages isolated development environments using git worktrees. Each worktree provides a separate working directory for independent Claude Code sessions, enabling 2-4 parallel development tasks.

**Key Benefit:** Complete file isolation between parallel tasks. No stashing or branch switching needed.

## Usage

```
/worktree list                    # List all worktrees with status
/worktree create <name>           # Create worktree with inferred branch
/worktree create <name> <branch>  # Create worktree for existing branch
/worktree open <name>             # Reopen worktree in VS Code
/worktree remove <name>           # Remove worktree (with safety checks)
/worktree status                  # Show current worktree context
/worktree cleanup                 # Clean DerivedData from inactive worktrees
```

## Naming Convention

Worktrees are created as siblings to the main repo with `unamentis-<name>` naming:

```
/Users/ramerman/dev/
├── unamentis/                    # Main repo
├── unamentis-kb-feature/         # Worktree: /worktree create kb-feature
└── unamentis-fix-crash/          # Worktree: /worktree create fix-crash
```

## Workflow

### `/worktree list`

1. Run `git worktree list -v`
2. For each worktree, show:
   - Path
   - Branch name
   - Whether it's the current worktree (marked with `*`)
   - DerivedData size if present
3. Show total count and disk usage

**Commands:**
```bash
git worktree list -v
# For each worktree path, check DerivedData:
du -sh <worktree>/DerivedData 2>/dev/null
```

### `/worktree create <name> [branch]`

1. **Validate name:** alphanumeric and hyphens only
2. **Infer branch** (if not specified):
   - `fix-*` → `fix/<rest>` (e.g., `fix-crash` → `fix/crash`)
   - `feat-*` or `feature-*` → `feature/<rest>`
   - `docs-*` → `docs/<rest>`
   - `refactor-*` → `refactor/<rest>`
   - `test-*` → `test/<rest>`
   - Default: `feature/<name>`
3. **Determine repo name:** Extract from current directory (e.g., `unamentis`)
4. **Create worktree:**
   ```bash
   git worktree add -b <branch> ../<repo>-<name>
   # Or for existing branch:
   git worktree add ../<repo>-<name> <branch>
   ```
5. **Auto-open in VS Code:**
   ```bash
   code ../<repo>-<name>
   ```
6. **Remind user:** "Run `/mcp-setup ios` in the new session"

### `/worktree open <name>`

1. Verify worktree exists at `../<repo>-<name>`
2. Open in VS Code:
   ```bash
   code ../<repo>-<name>
   ```
3. Remind about `/mcp-setup ios`

### `/worktree remove <name>`

1. **Check for uncommitted changes:**
   ```bash
   cd ../<repo>-<name> && git status --porcelain
   ```
   If dirty, warn and ask for confirmation.

2. **Check for unpushed commits:**
   ```bash
   cd ../<repo>-<name> && git log @{u}..HEAD --oneline 2>/dev/null
   ```
   If ahead of remote, warn and ask for confirmation.

3. **Remove worktree:**
   ```bash
   git worktree remove ../<repo>-<name>
   git worktree prune -v
   ```

### `/worktree status`

1. Detect if running in a worktree vs main repo:
   ```bash
   git rev-parse --is-inside-work-tree
   cat .git  # If file (not dir), this is a worktree
   ```
2. Show current branch
3. Show path to main repo
4. List sibling worktrees

### `/worktree cleanup`

1. List all worktrees with DerivedData:
   ```bash
   for wt in $(git worktree list --porcelain | grep "^worktree" | cut -d' ' -f2); do
     if [ -d "$wt/DerivedData" ]; then
       du -sh "$wt/DerivedData"
     fi
   done
   ```
2. Identify inactive worktrees (not current)
3. Ask for confirmation
4. Remove DerivedData from confirmed worktrees:
   ```bash
   rm -rf <worktree>/DerivedData
   ```
5. Report space recovered

## Examples

**Create worktree for a feature:**
```
User: /worktree create kb-improvements
Claude: Creating worktree for parallel development...

Branch: feature/kb-improvements (inferred from name)
Path: /Users/ramerman/dev/unamentis-kb-improvements/

✓ Worktree created
✓ Opening in VS Code...

New window opened. Run /mcp-setup ios in the new session to configure MCP.
```

**Create worktree for a bug fix:**
```
User: /worktree create fix-answer-validation
Claude: Creating worktree for parallel development...

Branch: fix/answer-validation (inferred from 'fix-' prefix)
Path: /Users/ramerman/dev/unamentis-fix-answer-validation/

✓ Worktree created
✓ Opening in VS Code...

New window opened. Run /mcp-setup ios in the new session.
```

**Create worktree for existing branch:**
```
User: /worktree create review feature/knowledge-bowl-2
Claude: Creating worktree for parallel development...

Branch: feature/knowledge-bowl-2 (existing)
Path: /Users/ramerman/dev/unamentis-review/

✓ Worktree created
✓ Opening in VS Code...

New window opened. Run /mcp-setup ios in the new session.
```

**List all worktrees:**
```
User: /worktree list
Claude: Git Worktrees:

  * /Users/ramerman/dev/unamentis (main) ← current
    /Users/ramerman/dev/unamentis-kb-ui (feature/kb-ui)
      DerivedData: 2.3 GB
    /Users/ramerman/dev/unamentis-fix-crash (fix/crash)
      DerivedData: 1.8 GB

Total: 3 worktrees, 4.1 GB DerivedData
```

**Check current status:**
```
User: /worktree status
Claude: Worktree Status:

Location: /Users/ramerman/dev/unamentis-kb-ui (worktree)
Branch: feature/kb-ui
Main repo: /Users/ramerman/dev/unamentis

Sibling worktrees:
- unamentis-fix-crash (fix/crash)
```

**Remove a worktree:**
```
User: /worktree remove kb-ui
Claude: Checking worktree status...

⚠️  Warning: 2 uncommitted changes detected
⚠️  Warning: 3 commits not pushed to remote

Are you sure you want to remove unamentis-kb-ui? (This cannot be undone)
[After confirmation]
✓ Worktree removed
✓ Stale references pruned
```

**Clean up DerivedData:**
```
User: /worktree cleanup
Claude: Checking DerivedData in worktrees...

Worktrees with DerivedData:
- unamentis-kb-ui: 2.3 GB (inactive)
- unamentis-fix-crash: 1.8 GB (inactive)

Clean DerivedData from inactive worktrees? (4.1 GB)
[After confirmation]
✓ Cleaned 4.1 GB from 2 worktrees
```

## Integration

- **Run `/mcp-setup ios`** in each new worktree session to configure MCP
- Each worktree has **independent MCP connections**
- `CLAUDE.md` is shared (read from the repo, same across all worktrees)
- Each VS Code window runs its own Claude Code session

## Disk Space Considerations

Each worktree accumulates its own build artifacts:

| Artifact | Typical Size | Location |
|----------|--------------|----------|
| Xcode DerivedData | 2-5 GB | `<worktree>/DerivedData/` |
| node_modules | 500 MB - 2 GB | `<worktree>/server/*/node_modules/` |
| Cargo target | 500 MB - 1 GB | `<worktree>/server/usm-core/target/` |

With 3-4 active worktrees, this can consume 10-20 GB. Use `/worktree cleanup` regularly.

## Quick Reference

```bash
# Git worktree commands (for reference)
git worktree add -b <branch> <path>    # Create with new branch
git worktree add <path> <branch>       # Create for existing branch
git worktree list -v                   # List all worktrees
git worktree remove <path>             # Remove worktree
git worktree prune -v                  # Clean stale references
```
