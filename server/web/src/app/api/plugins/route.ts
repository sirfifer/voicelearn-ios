import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

/**
 * GET /api/plugins
 * Get all discovered plugins with their status
 */
export async function GET() {
  try {
    const response = await fetch(`${BACKEND_URL}/api/plugins`, {
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
    console.error('Error fetching plugins:', error);
    return NextResponse.json(
      {
        success: false,
        plugins: [],
        error: 'Failed to fetch plugins',
      },
      { status: 503 }
    );
  }
}

/**
 * POST /api/plugins
 * Initialize plugins (first-run setup)
 */
export async function POST(request: Request) {
  try {
    const body = await request.json();

    const response = await fetch(`${BACKEND_URL}/api/plugins/initialize`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      return NextResponse.json(
        { success: false, error: error.error || `Backend returned ${response.status}` },
        { status: response.status }
      );
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error initializing plugins:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to initialize plugins' },
      { status: 503 }
    );
  }
}
