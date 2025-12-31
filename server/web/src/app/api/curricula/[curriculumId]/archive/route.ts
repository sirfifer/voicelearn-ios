import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

interface RouteContext {
  params: Promise<{ curriculumId: string }>;
}

/**
 * POST /api/curricula/[curriculumId]/archive
 * Archive a curriculum
 */
export async function POST(request: Request, context: RouteContext) {
  try {
    const { curriculumId } = await context.params;
    const response = await fetch(`${BACKEND_URL}/api/curricula/${curriculumId}/archive`, {
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
    console.error('Error archiving curriculum:', error);
    return NextResponse.json(
      { status: 'error', error: 'Failed to archive curriculum' },
      { status: 503 }
    );
  }
}

/**
 * DELETE /api/curricula/[curriculumId]/archive
 * Unarchive a curriculum
 */
export async function DELETE(request: Request, context: RouteContext) {
  try {
    const { curriculumId } = await context.params;
    const response = await fetch(`${BACKEND_URL}/api/curricula/${curriculumId}/archive`, {
      method: 'DELETE',
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
    console.error('Error unarchiving curriculum:', error);
    return NextResponse.json(
      { status: 'error', error: 'Failed to unarchive curriculum' },
      { status: 503 }
    );
  }
}
