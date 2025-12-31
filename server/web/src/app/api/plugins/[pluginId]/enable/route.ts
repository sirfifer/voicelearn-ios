import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

interface RouteContext {
  params: Promise<{ pluginId: string }>;
}

/**
 * POST /api/plugins/[pluginId]/enable
 * Enable a plugin
 */
export async function POST(request: Request, context: RouteContext) {
  try {
    const { pluginId } = await context.params;

    const response = await fetch(`${BACKEND_URL}/api/plugins/${pluginId}/enable`, {
      method: 'POST',
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
    console.error('Error enabling plugin:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to enable plugin' },
      { status: 503 }
    );
  }
}
