import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

interface RouteContext {
  params: Promise<{ curriculumId: string }>;
}

/**
 * GET /api/curricula/[curriculumId]/full
 * Get full curriculum with all topics and content
 */
export async function GET(request: Request, context: RouteContext) {
  try {
    const { curriculumId } = await context.params;
    const response = await fetch(`${BACKEND_URL}/api/curricula/${curriculumId}/full`, {
      headers: {
        'Content-Type': 'application/json',
      },
      next: { revalidate: 0 },
    });

    if (!response.ok) {
      if (response.status === 404) {
        return NextResponse.json(
          { error: 'Curriculum not found' },
          { status: 404 }
        );
      }
      throw new Error(`Backend returned ${response.status}`);
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error fetching full curriculum:', error);
    return NextResponse.json(
      { error: 'Failed to fetch curriculum details' },
      { status: 503 }
    );
  }
}
