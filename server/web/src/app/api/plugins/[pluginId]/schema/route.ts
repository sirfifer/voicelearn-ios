import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

interface RouteContext {
  params: Promise<{ pluginId: string }>;
}

/**
 * GET /api/plugins/[pluginId]/schema
 * Get the configuration schema for a plugin
 */
export async function GET(request: Request, context: RouteContext) {
  try {
    const { pluginId } = await context.params;
    const response = await fetch(`${BACKEND_URL}/api/plugins/${pluginId}/schema`, {
      headers: {
        'Content-Type': 'application/json',
      },
      next: { revalidate: 60 }, // Cache schema for 1 minute
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
    console.error('Error fetching plugin schema:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to fetch plugin schema' },
      { status: 503 }
    );
  }
}
