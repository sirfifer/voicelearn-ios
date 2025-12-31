import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

interface RouteContext {
  params: Promise<{ pluginId: string }>;
}

/**
 * POST /api/plugins/[pluginId]/test
 * Test plugin configuration (e.g., API key validation)
 */
export async function POST(request: Request, context: RouteContext) {
  try {
    const { pluginId } = await context.params;
    const body = await request.json();

    const response = await fetch(`${BACKEND_URL}/api/plugins/${pluginId}/test`, {
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
    console.error('Error testing plugin:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to test plugin configuration' },
      { status: 503 }
    );
  }
}
