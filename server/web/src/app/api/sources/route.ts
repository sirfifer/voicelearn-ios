import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

/**
 * GET /api/sources
 * Get generic source UI configuration for dynamic plugin rendering
 * This endpoint allows plugins to define their own UI configuration
 */
export async function GET() {
  try {
    const response = await fetch(`${BACKEND_URL}/api/sources`, {
      headers: {
        'Content-Type': 'application/json',
      },
      next: { revalidate: 60 }, // Cache for 1 minute
    });

    if (!response.ok) {
      throw new Error(`Backend returned ${response.status}`);
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error fetching sources:', error);
    return NextResponse.json(
      {
        success: false,
        sources: [],
        error: 'Failed to fetch sources',
      },
      { status: 503 }
    );
  }
}
