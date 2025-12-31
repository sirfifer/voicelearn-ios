import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

interface RouteContext {
  params: Promise<{ curriculumId: string; topicId: string }>;
}

/**
 * GET /api/curricula/[curriculumId]/topics/[topicId]/assets
 * Get all visual assets for a topic
 */
export async function GET(request: Request, context: RouteContext) {
  try {
    const { curriculumId, topicId } = await context.params;
    const response = await fetch(
      `${BACKEND_URL}/api/curricula/${curriculumId}/topics/${topicId}/assets`,
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
          { error: 'Topic not found' },
          { status: 404 }
        );
      }
      throw new Error(`Backend returned ${response.status}`);
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error fetching assets:', error);
    return NextResponse.json(
      { error: 'Failed to fetch assets' },
      { status: 503 }
    );
  }
}

/**
 * POST /api/curricula/[curriculumId]/topics/[topicId]/assets
 * Upload a new visual asset
 */
export async function POST(request: Request, context: RouteContext) {
  try {
    const { curriculumId, topicId } = await context.params;
    const formData = await request.formData();

    const response = await fetch(
      `${BACKEND_URL}/api/curricula/${curriculumId}/topics/${topicId}/assets`,
      {
        method: 'POST',
        body: formData,
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
    console.error('Error uploading asset:', error);
    return NextResponse.json(
      { status: 'error', error: 'Failed to upload asset' },
      { status: 503 }
    );
  }
}
