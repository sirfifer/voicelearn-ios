import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

interface RouteContext {
  params: Promise<{ pluginId: string }>;
}

/**
 * GET /api/plugins/[pluginId]
 * Get plugin details including configuration schema
 */
export async function GET(request: Request, context: RouteContext) {
  try {
    const { pluginId } = await context.params;
    const response = await fetch(`${BACKEND_URL}/api/plugins/${pluginId}`, {
      headers: {
        'Content-Type': 'application/json',
      },
      next: { revalidate: 0 },
    });

    if (!response.ok) {
      if (response.status === 404) {
        return NextResponse.json(
          { success: false, error: 'Plugin not found' },
          { status: 404 }
        );
      }
      throw new Error(`Backend returned ${response.status}`);
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error fetching plugin:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch plugin' },
      { status: 503 }
    );
  }
}

/**
 * PUT /api/plugins/[pluginId]
 * Update plugin settings
 */
export async function PUT(request: Request, context: RouteContext) {
  try {
    const { pluginId } = await context.params;
    const body = await request.json();

    const response = await fetch(`${BACKEND_URL}/api/plugins/${pluginId}`, {
      method: 'PUT',
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
    console.error('Error updating plugin:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to update plugin' },
      { status: 503 }
    );
  }
}
