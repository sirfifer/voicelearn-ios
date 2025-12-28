#!/usr/bin/env python3
"""
UnaMentis Project Effort Estimation Report Generator

Generates a reproducible effort estimation report based on codebase statistics.
Outputs timestamped HTML reports and maintains an index page for historical browsing.

Usage:
    python3 scripts/generate-effort-report.py

Output:
    docs/effort-reports/YYYY-MM-DD.html  - Timestamped report
    docs/effort-reports/index.html       - Index with current stats + history
"""

import subprocess
import os
from datetime import datetime
from pathlib import Path

# =============================================================================
# CONFIGURATION - Estimation Parameters
# =============================================================================

# Lines of code per hour by code type (mid-senior developer, greenfield project)
LOC_PER_HOUR = {
    "swift_complex": 17.5,      # Real-time audio, CoreData, ML integration
    "python_backend": 27.5,     # Standard web services, plugin architecture
    "typescript_react": 27.5,   # Modern framework, component-based
    "documentation": 45.0,      # Technical writing, specifications
}

# AI assistance adjustment factor
# AI-assisted projects produce 3-4x more output per hour
# Using 3.5x as midpoint
AI_ADJUSTMENT_FACTOR = 3.5

# Planning/architecture overhead percentage
PLANNING_OVERHEAD_PERCENT = 15

# Work hours
HOURS_PER_WEEK = 40
HOURS_PER_MONTH = 173  # Average business month

# =============================================================================
# DATA COLLECTION
# =============================================================================

def run_cmd(cmd: str) -> str:
    """Run a shell command and return stripped output."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip()

def count_files(path: str, pattern: str, exclude: list[str] = None) -> int:
    """Count files matching pattern in path."""
    exclude = exclude or []
    exclude_args = " ".join(f"! -path '{e}'" for e in exclude)
    cmd = f"find {path} -name '{pattern}' {exclude_args} 2>/dev/null | wc -l"
    return int(run_cmd(cmd) or 0)

def count_lines(path: str, pattern: str, exclude: list[str] = None) -> int:
    """Count lines in files matching pattern."""
    exclude = exclude or []
    exclude_args = " ".join(f"! -path '{e}'" for e in exclude)
    cmd = f"find {path} -name '{pattern}' {exclude_args} -exec cat {{}} \\; 2>/dev/null | wc -l"
    return int(run_cmd(cmd) or 0)

def count_lines_multi(path: str, patterns: list[str], exclude: list[str] = None) -> int:
    """Count lines in files matching multiple patterns."""
    exclude = exclude or []
    exclude_args = " ".join(f"! -path '{e}'" for e in exclude)
    pattern_args = " -o ".join(f"-name '{p}'" for p in patterns)
    cmd = f"find {path} \\( {pattern_args} \\) {exclude_args} -exec cat {{}} \\; 2>/dev/null | wc -l"
    return int(run_cmd(cmd) or 0)

def get_git_commits() -> int:
    """Get total number of git commits."""
    return int(run_cmd("git rev-list --count HEAD") or 0)

def get_git_branch() -> str:
    """Get current git branch."""
    return run_cmd("git rev-parse --abbrev-ref HEAD")

def collect_statistics() -> dict:
    """Collect all codebase statistics."""
    stats = {}

    # iOS App
    stats["ios_app_files"] = count_files("./UnaMentis", "*.swift")
    stats["ios_app_lines"] = count_lines("./UnaMentis", "*.swift")

    # iOS Tests
    stats["ios_test_files"] = count_files("./UnaMentisTests", "*.swift")
    stats["ios_test_lines"] = count_lines("./UnaMentisTests", "*.swift")

    # Server Python
    stats["server_py_files"] = count_files("./server", "*.py", ["*/__pycache__/*"])
    stats["server_py_lines"] = count_lines("./server", "*.py", ["*/__pycache__/*"])

    # Operations Console (Next.js)
    stats["web_ts_files"] = count_files("./server/web/src", "*.ts") + count_files("./server/web/src", "*.tsx")
    stats["web_ts_lines"] = count_lines_multi("./server/web/src", ["*.ts", "*.tsx"])

    # Management Console
    stats["mgmt_files"] = count_files("./server/management/static", "*.js") + \
                          count_files("./server/management/static", "*.html") + \
                          count_files("./server/management/static", "*.css")
    stats["mgmt_lines"] = count_lines_multi("./server/management/static", ["*.js", "*.html", "*.css"])

    # Scripts
    stats["script_files"] = count_files("./scripts", "*.sh")
    stats["script_lines"] = count_lines("./scripts", "*.sh")

    # Documentation
    stats["doc_files"] = count_files("./docs", "*.md")
    stats["doc_lines"] = count_lines("./docs", "*.md")

    # Curriculum
    stats["curriculum_files"] = count_files("./curriculum", "*.md") + \
                                 count_files("./curriculum", "*.json") + \
                                 count_files("./curriculum", "*.yaml")
    stats["curriculum_lines"] = count_lines_multi("./curriculum", ["*.md", "*.json", "*.yaml"])

    # Git stats
    stats["git_commits"] = get_git_commits()
    stats["git_branch"] = get_git_branch()

    # Service counts
    stats["llm_services"] = count_files("./UnaMentis/Services/LLM", "*.swift")
    stats["stt_services"] = count_files("./UnaMentis/Services/STT", "*.swift")
    stats["tts_services"] = count_files("./UnaMentis/Services/TTS", "*.swift")
    stats["vad_services"] = count_files("./UnaMentis/Services/VAD", "*.swift")

    # Core modules
    stats["core_modules"] = int(run_cmd("find ./UnaMentis/Core -type d -maxdepth 1 | tail -n +2 | wc -l") or 0)

    # UI modules
    stats["ui_modules"] = int(run_cmd("find ./UnaMentis/UI -type d -maxdepth 1 | tail -n +2 | wc -l") or 0)

    # Managed objects
    stats["managed_objects"] = count_files("./UnaMentis/Core/Persistence/ManagedObjects", "*.swift")

    # App intents
    stats["app_intents"] = count_files("./UnaMentis/Intents", "*.swift")

    return stats

# =============================================================================
# EFFORT CALCULATION
# =============================================================================

def calculate_effort(stats: dict) -> dict:
    """Calculate effort estimates based on statistics."""
    calc = {}

    # Combined totals
    calc["total_swift_lines"] = stats["ios_app_lines"] + stats["ios_test_lines"]
    calc["total_python_lines"] = stats["server_py_lines"]
    calc["total_ts_lines"] = stats["web_ts_lines"] + stats["mgmt_lines"]
    calc["total_doc_lines"] = stats["doc_lines"] + stats["curriculum_lines"]

    calc["total_source_files"] = (
        stats["ios_app_files"] + stats["ios_test_files"] +
        stats["server_py_files"] + stats["web_ts_files"] +
        stats["mgmt_files"] + stats["script_files"]
    )
    calc["total_source_lines"] = (
        calc["total_swift_lines"] + calc["total_python_lines"] +
        calc["total_ts_lines"] + stats["script_lines"]
    )

    # Hours by component (raw, no AI adjustment)
    calc["swift_hours"] = calc["total_swift_lines"] / LOC_PER_HOUR["swift_complex"]
    calc["python_hours"] = calc["total_python_lines"] / LOC_PER_HOUR["python_backend"]
    calc["ts_hours"] = calc["total_ts_lines"] / LOC_PER_HOUR["typescript_react"]
    calc["doc_hours"] = calc["total_doc_lines"] / LOC_PER_HOUR["documentation"]

    calc["raw_total_hours"] = (
        calc["swift_hours"] + calc["python_hours"] +
        calc["ts_hours"] + calc["doc_hours"]
    )

    # With planning overhead (no AI adjustment) = HUMAN ONLY ESTIMATE
    calc["human_hours"] = calc["raw_total_hours"] * (1 + PLANNING_OVERHEAD_PERCENT / 100)
    calc["human_weeks"] = calc["human_hours"] / HOURS_PER_WEEK
    calc["human_months"] = calc["human_hours"] / HOURS_PER_MONTH

    # With AI adjustment = AI-ASSISTED ESTIMATE
    calc["ai_adjusted_hours"] = calc["raw_total_hours"] / AI_ADJUSTMENT_FACTOR
    calc["ai_with_overhead_hours"] = calc["ai_adjusted_hours"] * (1 + PLANNING_OVERHEAD_PERCENT / 100)
    calc["ai_weeks"] = calc["ai_with_overhead_hours"] / HOURS_PER_WEEK
    calc["ai_months"] = calc["ai_with_overhead_hours"] / HOURS_PER_MONTH

    return calc

# =============================================================================
# HTML GENERATION
# =============================================================================

def generate_report_html(stats: dict, calc: dict, generated_at: datetime) -> str:
    """Generate the full HTML report."""

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>UnaMentis Effort Report - {generated_at.strftime("%Y-%m-%d")}</title>
    <style>
        :root {{
            --primary: #2563eb;
            --primary-dark: #1d4ed8;
            --success: #059669;
            --warning: #d97706;
            --bg: #f8fafc;
            --card-bg: #ffffff;
            --text: #1e293b;
            --text-muted: #64748b;
            --border: #e2e8f0;
        }}
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: var(--bg);
            color: var(--text);
            line-height: 1.6;
            padding: 2rem;
        }}
        .container {{ max-width: 1000px; margin: 0 auto; }}
        h1 {{ font-size: 2rem; margin-bottom: 0.5rem; }}
        h2 {{ font-size: 1.5rem; margin: 2rem 0 1rem; color: var(--primary-dark); border-bottom: 2px solid var(--border); padding-bottom: 0.5rem; }}
        h3 {{ font-size: 1.1rem; margin: 1.5rem 0 0.75rem; color: var(--text); }}
        .meta {{ color: var(--text-muted); margin-bottom: 2rem; }}

        /* Executive Summary - Prominent */
        .executive-summary {{
            background: linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%);
            color: white;
            padding: 2rem;
            border-radius: 12px;
            margin-bottom: 2rem;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }}
        .executive-summary h2 {{
            color: white;
            border-bottom-color: rgba(255,255,255,0.3);
            margin-top: 0;
        }}
        .estimate-grid {{
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 1.5rem;
            margin-top: 1.5rem;
        }}
        .estimate-card {{
            background: rgba(255,255,255,0.15);
            border-radius: 8px;
            padding: 1.5rem;
            text-align: center;
        }}
        .estimate-card.primary {{
            background: rgba(255,255,255,0.25);
            border: 2px solid rgba(255,255,255,0.4);
        }}
        .estimate-label {{
            font-size: 0.875rem;
            opacity: 0.9;
            margin-bottom: 0.5rem;
        }}
        .estimate-value {{
            font-size: 2.5rem;
            font-weight: 700;
            line-height: 1.2;
        }}
        .estimate-unit {{
            font-size: 1rem;
            opacity: 0.8;
        }}
        .estimate-hours {{
            font-size: 0.875rem;
            opacity: 0.7;
            margin-top: 0.25rem;
        }}

        /* Cards */
        .card {{
            background: var(--card-bg);
            border-radius: 8px;
            padding: 1.5rem;
            margin-bottom: 1rem;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}

        /* Tables */
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 1rem 0;
        }}
        th, td {{
            padding: 0.75rem;
            text-align: left;
            border-bottom: 1px solid var(--border);
        }}
        th {{
            background: var(--bg);
            font-weight: 600;
            color: var(--text-muted);
            font-size: 0.875rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }}
        td {{ font-size: 0.95rem; }}
        tr:last-child td {{ border-bottom: none; }}
        .num {{ text-align: right; font-variant-numeric: tabular-nums; }}
        .total-row {{ font-weight: 600; background: var(--bg); }}

        /* Lists */
        ul {{ margin: 0.5rem 0; padding-left: 1.5rem; }}
        li {{ margin: 0.25rem 0; }}

        /* Methodology */
        .formula {{
            background: #f1f5f9;
            border-left: 4px solid var(--primary);
            padding: 1rem;
            margin: 1rem 0;
            font-family: 'SF Mono', Monaco, monospace;
            font-size: 0.875rem;
            overflow-x: auto;
        }}
        .param-table td:first-child {{
            font-weight: 600;
            color: var(--primary-dark);
        }}

        /* Footer */
        .footer {{
            margin-top: 3rem;
            padding-top: 1.5rem;
            border-top: 1px solid var(--border);
            color: var(--text-muted);
            font-size: 0.875rem;
            text-align: center;
        }}

        @media (max-width: 600px) {{
            .estimate-grid {{ grid-template-columns: 1fr; }}
            .estimate-value {{ font-size: 2rem; }}
            body {{ padding: 1rem; }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>UnaMentis Project Effort Estimation</h1>
        <p class="meta">Generated: {generated_at.strftime("%B %d, %Y at %H:%M")} · Branch: {stats["git_branch"]} · Commits: {stats["git_commits"]:,}</p>

        <!-- Executive Summary -->
        <div class="executive-summary">
            <h2>Executive Summary</h2>
            <div class="estimate-grid">
                <div class="estimate-card primary">
                    <div class="estimate-label">AI-Assisted Development (Actual)</div>
                    <div class="estimate-value">{calc["ai_months"]:.0f}-{calc["ai_months"]*1.3:.0f}</div>
                    <div class="estimate-unit">months</div>
                    <div class="estimate-hours">{calc["ai_with_overhead_hours"]:,.0f}-{calc["ai_with_overhead_hours"]*1.3:,.0f} man-hours</div>
                </div>
                <div class="estimate-card">
                    <div class="estimate-label">Pure Human Development (No AI)</div>
                    <div class="estimate-value">{calc["human_months"]:.0f}-{calc["human_months"]*1.15:.0f}</div>
                    <div class="estimate-unit">months</div>
                    <div class="estimate-hours">{calc["human_hours"]:,.0f}-{calc["human_hours"]*1.15:,.0f} man-hours</div>
                </div>
            </div>
            <p style="margin-top: 1.5rem; opacity: 0.9; font-size: 0.95rem;">
                Based on {calc["total_source_lines"]:,} lines of source code across {calc["total_source_files"]:,} files.
                Estimates assume a single mid-senior developer working 40 hours/week.
            </p>
        </div>

        <!-- Codebase Statistics -->
        <h2>Codebase Statistics</h2>

        <div class="card">
            <h3>Source Code by Component</h3>
            <table>
                <thead>
                    <tr><th>Component</th><th class="num">Files</th><th class="num">Lines</th></tr>
                </thead>
                <tbody>
                    <tr><td>iOS App (Swift)</td><td class="num">{stats["ios_app_files"]:,}</td><td class="num">{stats["ios_app_lines"]:,}</td></tr>
                    <tr><td>iOS Tests (Swift)</td><td class="num">{stats["ios_test_files"]:,}</td><td class="num">{stats["ios_test_lines"]:,}</td></tr>
                    <tr><td>Server (Python)</td><td class="num">{stats["server_py_files"]:,}</td><td class="num">{stats["server_py_lines"]:,}</td></tr>
                    <tr><td>Operations Console (TS/React)</td><td class="num">{stats["web_ts_files"]:,}</td><td class="num">{stats["web_ts_lines"]:,}</td></tr>
                    <tr><td>Management Console (JS/HTML/CSS)</td><td class="num">{stats["mgmt_files"]:,}</td><td class="num">{stats["mgmt_lines"]:,}</td></tr>
                    <tr><td>Shell Scripts</td><td class="num">{stats["script_files"]:,}</td><td class="num">{stats["script_lines"]:,}</td></tr>
                    <tr class="total-row"><td>Total Source Code</td><td class="num">{calc["total_source_files"]:,}</td><td class="num">{calc["total_source_lines"]:,}</td></tr>
                </tbody>
            </table>
        </div>

        <div class="card">
            <h3>Documentation & Specifications</h3>
            <table>
                <thead>
                    <tr><th>Type</th><th class="num">Files</th><th class="num">Lines</th></tr>
                </thead>
                <tbody>
                    <tr><td>Technical Documentation</td><td class="num">{stats["doc_files"]:,}</td><td class="num">{stats["doc_lines"]:,}</td></tr>
                    <tr><td>Curriculum Specification</td><td class="num">{stats["curriculum_files"]:,}</td><td class="num">{stats["curriculum_lines"]:,}</td></tr>
                    <tr class="total-row"><td>Total Documentation</td><td class="num">{stats["doc_files"] + stats["curriculum_files"]:,}</td><td class="num">{calc["total_doc_lines"]:,}</td></tr>
                </tbody>
            </table>
        </div>

        <!-- Architecture -->
        <h2>Architectural Complexity</h2>

        <div class="card">
            <h3>iOS Application Architecture</h3>
            <table>
                <thead>
                    <tr><th>Component</th><th class="num">Count</th></tr>
                </thead>
                <tbody>
                    <tr><td>LLM Service Providers</td><td class="num">{stats["llm_services"]}</td></tr>
                    <tr><td>STT Service Providers</td><td class="num">{stats["stt_services"]}</td></tr>
                    <tr><td>TTS Service Providers</td><td class="num">{stats["tts_services"]}</td></tr>
                    <tr><td>VAD Services</td><td class="num">{stats["vad_services"]}</td></tr>
                    <tr><td>Core System Modules</td><td class="num">{stats["core_modules"]}</td></tr>
                    <tr><td>UI View Modules</td><td class="num">{stats["ui_modules"]}</td></tr>
                    <tr><td>CoreData Managed Objects</td><td class="num">{stats["managed_objects"]}</td></tr>
                    <tr><td>App Intents (Siri Shortcuts)</td><td class="num">{stats["app_intents"]}</td></tr>
                </tbody>
            </table>
        </div>

        <!-- Calculation Breakdown -->
        <h2>Effort Calculation</h2>

        <div class="card">
            <h3>Hours by Component (Raw)</h3>
            <table>
                <thead>
                    <tr><th>Component</th><th class="num">Lines</th><th class="num">LOC/Hour</th><th class="num">Hours</th></tr>
                </thead>
                <tbody>
                    <tr><td>iOS Swift (complex audio/ML)</td><td class="num">{calc["total_swift_lines"]:,}</td><td class="num">{LOC_PER_HOUR["swift_complex"]}</td><td class="num">{calc["swift_hours"]:,.0f}</td></tr>
                    <tr><td>Python Backend</td><td class="num">{calc["total_python_lines"]:,}</td><td class="num">{LOC_PER_HOUR["python_backend"]}</td><td class="num">{calc["python_hours"]:,.0f}</td></tr>
                    <tr><td>TypeScript/React</td><td class="num">{calc["total_ts_lines"]:,}</td><td class="num">{LOC_PER_HOUR["typescript_react"]}</td><td class="num">{calc["ts_hours"]:,.0f}</td></tr>
                    <tr><td>Documentation</td><td class="num">{calc["total_doc_lines"]:,}</td><td class="num">{LOC_PER_HOUR["documentation"]}</td><td class="num">{calc["doc_hours"]:,.0f}</td></tr>
                    <tr class="total-row"><td>Raw Total</td><td class="num"></td><td class="num"></td><td class="num">{calc["raw_total_hours"]:,.0f}</td></tr>
                </tbody>
            </table>
        </div>

        <div class="card">
            <h3>Final Estimates</h3>

            <h4 style="margin-top: 1rem;">Pure Human Development (No AI)</h4>
            <div class="formula">
Raw Hours ({calc["raw_total_hours"]:,.0f}) × Planning Overhead (1.{PLANNING_OVERHEAD_PERCENT}) = {calc["human_hours"]:,.0f} hours
{calc["human_hours"]:,.0f} hours ÷ {HOURS_PER_WEEK} hrs/week = {calc["human_weeks"]:.1f} weeks
{calc["human_hours"]:,.0f} hours ÷ {HOURS_PER_MONTH} hrs/month = {calc["human_months"]:.1f} months
            </div>

            <h4 style="margin-top: 1.5rem;">AI-Assisted Development</h4>
            <div class="formula">
Raw Hours ({calc["raw_total_hours"]:,.0f}) ÷ AI Factor ({AI_ADJUSTMENT_FACTOR}) = {calc["ai_adjusted_hours"]:,.0f} hours
{calc["ai_adjusted_hours"]:,.0f} hours × Planning Overhead (1.{PLANNING_OVERHEAD_PERCENT}) = {calc["ai_with_overhead_hours"]:,.0f} hours
{calc["ai_with_overhead_hours"]:,.0f} hours ÷ {HOURS_PER_WEEK} hrs/week = {calc["ai_weeks"]:.1f} weeks
{calc["ai_with_overhead_hours"]:,.0f} hours ÷ {HOURS_PER_MONTH} hrs/month = {calc["ai_months"]:.1f} months
            </div>
        </div>

        <!-- Methodology -->
        <h2>Methodology</h2>

        <div class="card">
            <h3>Estimation Parameters</h3>
            <table class="param-table">
                <tbody>
                    <tr><td>Swift (complex)</td><td>{LOC_PER_HOUR["swift_complex"]} LOC/hour - Real-time audio, CoreData, ML integration</td></tr>
                    <tr><td>Python Backend</td><td>{LOC_PER_HOUR["python_backend"]} LOC/hour - Standard web services, plugin architecture</td></tr>
                    <tr><td>TypeScript/React</td><td>{LOC_PER_HOUR["typescript_react"]} LOC/hour - Modern framework, component-based</td></tr>
                    <tr><td>Documentation</td><td>{LOC_PER_HOUR["documentation"]} LOC/hour - Technical writing</td></tr>
                    <tr><td>AI Adjustment</td><td>÷{AI_ADJUSTMENT_FACTOR} - AI-assisted projects produce {AI_ADJUSTMENT_FACTOR}x output</td></tr>
                    <tr><td>Planning Overhead</td><td>+{PLANNING_OVERHEAD_PERCENT}% - Architecture and planning time</td></tr>
                    <tr><td>Work Week</td><td>{HOURS_PER_WEEK} hours</td></tr>
                    <tr><td>Work Month</td><td>{HOURS_PER_MONTH} hours (average business month)</td></tr>
                </tbody>
            </table>
        </div>

        <div class="card">
            <h3>Complexity Factors Considered</h3>
            <ul>
                <li>Real-time audio processing with &lt;500ms latency requirement</li>
                <li>On-device ML integration (llama.cpp, Silero VAD)</li>
                <li>Multiple third-party API integrations ({stats["llm_services"] + stats["stt_services"] + stats["tts_services"]}+ external services)</li>
                <li>CoreData persistence layer with {stats["managed_objects"]} entity types</li>
                <li>Swift 6.0 with C++ interoperability</li>
                <li>Multi-platform considerations (iOS 18+)</li>
            </ul>
        </div>

        <div class="footer">
            <p>Generated by <code>scripts/generate-effort-report.py</code></p>
            <p>UnaMentis - Voice AI Tutoring Platform</p>
        </div>
    </div>
</body>
</html>
'''

def generate_index_html(reports: list[dict], latest: dict) -> str:
    """Generate the index page with current stats and history."""

    history_rows = "\n".join(
        f'<tr><td><a href="{r["filename"]}">{r["date"]}</a></td>'
        f'<td class="num">{r["commits"]:,}</td>'
        f'<td class="num">{r["source_lines"]:,}</td>'
        f'<td class="num">{r["source_files"]:,}</td></tr>'
        for r in reports
    )

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>UnaMentis Effort Reports</title>
    <style>
        :root {{
            --primary: #2563eb;
            --primary-dark: #1d4ed8;
            --bg: #f8fafc;
            --card-bg: #ffffff;
            --text: #1e293b;
            --text-muted: #64748b;
            --border: #e2e8f0;
        }}
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: var(--bg);
            color: var(--text);
            line-height: 1.6;
            padding: 2rem;
        }}
        .container {{ max-width: 900px; margin: 0 auto; }}
        h1 {{ font-size: 2rem; margin-bottom: 0.5rem; }}
        h2 {{ font-size: 1.25rem; margin: 2rem 0 1rem; color: var(--primary-dark); }}
        .meta {{ color: var(--text-muted); margin-bottom: 2rem; }}

        .current-stats {{
            background: linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%);
            color: white;
            padding: 2rem;
            border-radius: 12px;
            margin-bottom: 2rem;
        }}
        .current-stats h2 {{ color: white; margin-top: 0; }}
        .stats-grid {{
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 1rem;
            margin-top: 1rem;
        }}
        .stat-box {{
            background: rgba(255,255,255,0.15);
            padding: 1rem;
            border-radius: 8px;
            text-align: center;
        }}
        .stat-value {{ font-size: 1.75rem; font-weight: 700; }}
        .stat-label {{ font-size: 0.8rem; opacity: 0.8; }}

        .card {{
            background: var(--card-bg);
            border-radius: 8px;
            padding: 1.5rem;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}

        table {{ width: 100%; border-collapse: collapse; }}
        th, td {{ padding: 0.75rem; text-align: left; border-bottom: 1px solid var(--border); }}
        th {{ background: var(--bg); font-weight: 600; color: var(--text-muted); font-size: 0.875rem; }}
        .num {{ text-align: right; font-variant-numeric: tabular-nums; }}
        a {{ color: var(--primary); text-decoration: none; }}
        a:hover {{ text-decoration: underline; }}

        .view-latest {{
            display: inline-block;
            background: white;
            color: var(--primary-dark);
            padding: 0.75rem 1.5rem;
            border-radius: 6px;
            font-weight: 600;
            margin-top: 1rem;
            text-decoration: none;
        }}
        .view-latest:hover {{ background: #f1f5f9; text-decoration: none; }}

        @media (max-width: 600px) {{
            .stats-grid {{ grid-template-columns: repeat(2, 1fr); }}
            body {{ padding: 1rem; }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>UnaMentis Effort Reports</h1>
        <p class="meta">Historical tracking of project size and effort estimates</p>

        <div class="current-stats">
            <h2>Current Status</h2>
            <div class="stats-grid">
                <div class="stat-box">
                    <div class="stat-value">{latest["ai_months"]:.0f}-{latest["ai_months"]*1.3:.0f}</div>
                    <div class="stat-label">AI-Assisted (months)</div>
                </div>
                <div class="stat-box">
                    <div class="stat-value">{latest["human_months"]:.0f}-{latest["human_months"]*1.15:.0f}</div>
                    <div class="stat-label">Human Only (months)</div>
                </div>
                <div class="stat-box">
                    <div class="stat-value">{latest["source_lines"]:,}</div>
                    <div class="stat-label">Lines of Code</div>
                </div>
                <div class="stat-box">
                    <div class="stat-value">{latest["commits"]:,}</div>
                    <div class="stat-label">Commits</div>
                </div>
            </div>
            <a href="{latest["filename"]}" class="view-latest">View Full Report →</a>
        </div>

        <h2>Report History</h2>
        <div class="card">
            <table>
                <thead>
                    <tr>
                        <th>Date</th>
                        <th class="num">Commits</th>
                        <th class="num">Lines of Code</th>
                        <th class="num">Files</th>
                    </tr>
                </thead>
                <tbody>
                    {history_rows}
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
'''

# =============================================================================
# MAIN
# =============================================================================

def main():
    # Setup
    project_root = Path(__file__).parent.parent
    os.chdir(project_root)

    reports_dir = project_root / "docs" / "effort-reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    now = datetime.now()
    date_str = now.strftime("%Y-%m-%d")
    report_filename = f"{date_str}.html"
    report_path = reports_dir / report_filename
    index_path = reports_dir / "index.html"

    print(f"Generating effort report for {date_str}...")

    # Collect statistics
    print("  Collecting codebase statistics...")
    stats = collect_statistics()

    # Calculate effort
    print("  Calculating effort estimates...")
    calc = calculate_effort(stats)

    # Generate report HTML
    print("  Generating report HTML...")
    report_html = generate_report_html(stats, calc, now)
    report_path.write_text(report_html)
    print(f"  Written: {report_path}")

    # Collect all reports for index
    print("  Updating index...")
    reports = []
    for html_file in sorted(reports_dir.glob("????-??-??.html"), reverse=True):
        # Parse date from filename
        date = html_file.stem
        # For current report, use calculated values; for historical, we'd need to parse
        # For simplicity, just use current values for the latest
        if html_file.name == report_filename:
            reports.append({
                "filename": html_file.name,
                "date": date,
                "commits": stats["git_commits"],
                "source_lines": calc["total_source_lines"],
                "source_files": calc["total_source_files"],
            })
        else:
            # For older reports, try to extract from filename or use placeholder
            reports.append({
                "filename": html_file.name,
                "date": date,
                "commits": 0,  # Would need to parse from HTML
                "source_lines": 0,
                "source_files": 0,
            })

    # Latest data for index header
    latest = {
        "filename": report_filename,
        "ai_months": calc["ai_months"],
        "human_months": calc["human_months"],
        "source_lines": calc["total_source_lines"],
        "commits": stats["git_commits"],
    }

    # Generate index HTML
    index_html = generate_index_html(reports, latest)
    index_path.write_text(index_html)
    print(f"  Written: {index_path}")

    # Summary
    print()
    print("=" * 60)
    print("EFFORT ESTIMATION SUMMARY")
    print("=" * 60)
    print(f"Source Files:     {calc['total_source_files']:,}")
    print(f"Source Lines:     {calc['total_source_lines']:,}")
    print(f"Documentation:    {calc['total_doc_lines']:,} lines")
    print()
    print(f"AI-Assisted:      {calc['ai_months']:.0f}-{calc['ai_months']*1.3:.0f} months ({calc['ai_with_overhead_hours']:,.0f} hours)")
    print(f"Human Only:       {calc['human_months']:.0f}-{calc['human_months']*1.15:.0f} months ({calc['human_hours']:,.0f} hours)")
    print("=" * 60)

if __name__ == "__main__":
    main()
