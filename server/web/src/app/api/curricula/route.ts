import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

/**
 * GET /api/curricula
 * List all curricula with optional filtering
 */
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const queryString = searchParams.toString();
    const url = `${BACKEND_URL}/api/curricula${queryString ? `?${queryString}` : ''}`;

    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
      },
      next: { revalidate: 0 }, // No caching for dynamic data
    });

    if (!response.ok) {
      throw new Error(`Backend returned ${response.status}`);
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error fetching curricula:', error);
    return NextResponse.json(
      {
        curricula: [],
        total: 0,
        error: 'Failed to fetch curricula',
      },
      { status: 503 }
    );
  }
}

/**
 * POST /api/curricula
 * Import a new curriculum from file
 */
export async function POST(request: Request) {
  try {
    const contentType = request.headers.get('content-type') || '';

    let response: Response;

    if (contentType.includes('multipart/form-data')) {
      // Handle file upload
      const formData = await request.formData();
      response = await fetch(`${BACKEND_URL}/api/curricula/import`, {
        method: 'POST',
        body: formData,
      });
    } else {
      // Handle JSON body
      const body = await request.json();
      response = await fetch(`${BACKEND_URL}/api/curricula`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      });
    }

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
    console.error('Error creating curriculum:', error);
    return NextResponse.json(
      { status: 'error', error: 'Failed to create curriculum' },
      { status: 503 }
    );
  }
}
