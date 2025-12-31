import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

/**
 * POST /api/curricula/reload
 * Reload curricula from disk
 */
export async function POST() {
  try {
    const response = await fetch(`${BACKEND_URL}/api/curricula/reload`, {
      method: 'POST',
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      return NextResponse.json(
        { status: 'error', error: error.error || `Backend returned ${response.status}` },
        { status: response.status }
      );
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error reloading curricula:', error);
    return NextResponse.json(
      { status: 'error', error: 'Failed to reload curricula' },
      { status: 503 }
    );
  }
}
