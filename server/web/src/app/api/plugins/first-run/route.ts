import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

/**
 * GET /api/plugins/first-run
 * Check if first-run setup is needed
 */
export async function GET() {
  try {
    const response = await fetch(`${BACKEND_URL}/api/plugins/first-run`, {
      headers: {
        'Content-Type': 'application/json',
      },
      next: { revalidate: 0 },
    });

    if (!response.ok) {
      throw new Error(`Backend returned ${response.status}`);
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error checking first-run status:', error);
    return NextResponse.json(
      {
        success: false,
        firstRunNeeded: false,
        error: 'Failed to check first-run status',
      },
      { status: 503 }
    );
  }
}
