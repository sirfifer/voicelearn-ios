import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

/**
 * POST /api/tts/pregen/extract
 * Extract content from a source for preview before job creation
 *
 * Request body:
 * - source_type: 'knowledge-bowl' | 'curriculum' | 'custom'
 * - source_id: Source identifier (for KB/curriculum)
 * - include_questions: Include question text (default true)
 * - include_answers: Include answer text (default true)
 * - include_hints: Include hint text (default true)
 * - include_explanations: Include explanation text (default true)
 * - domains: Filter by domains (optional)
 * - difficulties: Filter by difficulty tiers (optional)
 *
 * Returns:
 * - items: Array of extracted items (text, source_ref)
 * - total_count: Total items extracted
 * - stats: Breakdown by domain, type, etc.
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    const response = await fetch(`${BACKEND_URL}/api/tts/pregen/extract`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    const data = await response.json();

    if (!response.ok) {
      return NextResponse.json(data, { status: response.status });
    }

    return NextResponse.json(data);
  } catch (error) {
    console.error('Error extracting content:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to extract content' },
      { status: 503 }
    );
  }
}
