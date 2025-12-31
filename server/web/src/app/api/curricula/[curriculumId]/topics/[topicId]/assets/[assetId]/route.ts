import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

interface RouteContext {
  params: Promise<{ curriculumId: string; topicId: string; assetId: string }>;
}

/**
 * GET /api/curricula/[curriculumId]/topics/[topicId]/assets/[assetId]
 * Get a specific visual asset
 */
export async function GET(request: Request, context: RouteContext) {
  try {
    const { curriculumId, topicId, assetId } = await context.params;
    const response = await fetch(
      `${BACKEND_URL}/api/curricula/${curriculumId}/topics/${topicId}/assets/${assetId}`,
      {
        headers: {
          'Content-Type': 'application/json',
        },
        next: { revalidate: 0 },
      }
    );

    if (!response.ok) {
      if (response.status === 404) {
        return NextResponse.json(
          { error: 'Asset not found' },
          { status: 404 }
        );
      }
      throw new Error(`Backend returned ${response.status}`);
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error fetching asset:', error);
    return NextResponse.json(
      { error: 'Failed to fetch asset' },
      { status: 503 }
    );
  }
}

/**
 * PATCH /api/curricula/[curriculumId]/topics/[topicId]/assets/[assetId]
 * Update asset metadata
 */
export async function PATCH(request: Request, context: RouteContext) {
  try {
    const { curriculumId, topicId, assetId } = await context.params;
    const body = await request.json();

    const response = await fetch(
      `${BACKEND_URL}/api/curricula/${curriculumId}/topics/${topicId}/assets/${assetId}`,
      {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
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
    console.error('Error updating asset:', error);
    return NextResponse.json(
      { status: 'error', error: 'Failed to update asset' },
      { status: 503 }
    );
  }
}

/**
 * DELETE /api/curricula/[curriculumId]/topics/[topicId]/assets/[assetId]
 * Delete a visual asset
 */
export async function DELETE(request: Request, context: RouteContext) {
  try {
    const { curriculumId, topicId, assetId } = await context.params;

    const response = await fetch(
      `${BACKEND_URL}/api/curricula/${curriculumId}/topics/${topicId}/assets/${assetId}`,
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
    console.error('Error deleting asset:', error);
    return NextResponse.json(
      { status: 'error', error: 'Failed to delete asset' },
      { status: 503 }
    );
  }
}
