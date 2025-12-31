import { NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8766';

interface RouteContext {
  params: Promise<{ curriculumId: string; topicId: string }>;
}

/**
 * GET /api/curricula/[curriculumId]/topics/[topicId]/transcript
 * Get transcript for a topic
 */
export async function GET(request: Request, context: RouteContext) {
  try {
    const { curriculumId, topicId } = await context.params;
    const response = await fetch(
      `${BACKEND_URL}/api/curricula/${curriculumId}/topics/${topicId}/transcript`,
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
    console.error('Error fetching transcript:', error);
    return NextResponse.json(
      { error: 'Failed to fetch transcript' },
      { status: 503 }
    );
  }
}
