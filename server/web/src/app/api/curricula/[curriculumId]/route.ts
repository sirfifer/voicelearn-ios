import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

interface RouteContext {
  params: Promise<{ curriculumId: string }>;
}

/**
 * GET /api/curricula/[curriculumId]
 * Get curriculum summary by ID
 */
export async function GET(request: Request, context: RouteContext) {
  try {
    const { curriculumId } = await context.params;
    const response = await fetch(`${BACKEND_URL}/api/curricula/${curriculumId}`, {
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
    console.error('Error fetching curriculum:', error);
    return NextResponse.json(
      { error: 'Failed to fetch curriculum' },
      { status: 503 }
    );
  }
}

/**
 * PUT /api/curricula/[curriculumId]
 * Update/save curriculum
 */
export async function PUT(request: Request, context: RouteContext) {
  try {
    const { curriculumId } = await context.params;
    const body = await request.json();

    const response = await fetch(`${BACKEND_URL}/api/curricula/${curriculumId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
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
    console.error('Error updating curriculum:', error);
    return NextResponse.json(
      { status: 'error', error: 'Failed to update curriculum' },
      { status: 503 }
    );
  }
}

/**
 * DELETE /api/curricula/[curriculumId]
 * Delete curriculum
 */
export async function DELETE(request: Request, context: RouteContext) {
  try {
    const { curriculumId } = await context.params;
    const { searchParams } = new URL(request.url);
    const confirm = searchParams.get('confirm');

    const response = await fetch(
      `${BACKEND_URL}/api/curricula/${curriculumId}${confirm ? '?confirm=true' : ''}`,
      {
        method: 'DELETE',
      }
    );

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
    console.error('Error deleting curriculum:', error);
    return NextResponse.json(
      { status: 'error', error: 'Failed to delete curriculum' },
      { status: 503 }
    );
  }
}
