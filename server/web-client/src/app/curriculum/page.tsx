'use client';

/**
 * Curriculum Page
 *
 * Browse and select curricula and topics for learning sessions.
 */

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Play } from 'lucide-react';
import { useAuth } from '@/components/auth/AuthProvider';
import { Button } from '@/components/ui';
import { CurriculumBrowser } from '@/components/curriculum';
import { useCurricula, useCurriculum } from '@/lib/api';
import type { CurriculumSummary, ContentNode, Curriculum } from '@/types';

export default function CurriculumPage() {
  const router = useRouter();
  const { isAuthenticated, isLoading: authLoading } = useAuth();
  const { data: curriculaData, isLoading: curriculaLoading, mutate: refreshCurricula } = useCurricula();
  const [selectedCurriculumId, setSelectedCurriculumId] = React.useState<string | null>(null);
  const [selectedTopicId, setSelectedTopicId] = React.useState<string | undefined>(undefined);

  // Fetch full curriculum details when selected
  const { data: curriculumData } = useCurriculum(selectedCurriculumId || '');
  const selectedCurriculum = curriculumData?.curriculum as Curriculum | undefined;

  // Redirect if not authenticated
  React.useEffect(() => {
    if (!authLoading && !isAuthenticated) {
      router.push('/login');
    }
  }, [isAuthenticated, authLoading, router]);

  const handleCurriculumSelect = React.useCallback((curriculum: CurriculumSummary) => {
    setSelectedCurriculumId(curriculum.id);
    setSelectedTopicId(undefined);
  }, []);

  const handleTopicSelect = React.useCallback((topic: ContentNode) => {
    // ContentNode.id is a CatalogId object, convert to string
    const topicId = typeof topic.id === 'string' ? topic.id : `${topic.id.catalog}:${topic.id.value}`;
    setSelectedTopicId(topicId);
  }, []);

  const handleStartSession = React.useCallback(() => {
    // Navigate to session with selected topic
    const params = new URLSearchParams();
    if (selectedCurriculumId) params.set('curriculum', selectedCurriculumId);
    if (selectedTopicId) params.set('topic', selectedTopicId);
    router.push(`/session?${params.toString()}`);
  }, [router, selectedCurriculumId, selectedTopicId]);

  const handleRefresh = React.useCallback(() => {
    refreshCurricula();
  }, [refreshCurricula]);

  if (authLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="text-center">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent mx-auto" />
          <p className="mt-4 text-muted-foreground">Loading...</p>
        </div>
      </main>
    );
  }

  if (!isAuthenticated) {
    return null;
  }

  const curricula = (curriculaData?.curricula || []) as CurriculumSummary[];

  return (
    <main className="flex flex-col h-screen">
      {/* Header */}
      <div className="flex items-center gap-2 px-4 py-3 border-b">
        <Button variant="ghost" size="icon" onClick={() => router.push('/')}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <h1 className="text-lg font-semibold flex-1">Browse Curricula</h1>
        {selectedTopicId && (
          <Button onClick={handleStartSession}>
            <Play className="h-4 w-4 mr-2" />
            Start Session
          </Button>
        )}
      </div>

      {/* Curriculum Browser */}
      <div className="flex-1 overflow-hidden">
        <CurriculumBrowser
          curricula={curricula}
          selectedCurriculum={selectedCurriculum || null}
          selectedTopicId={selectedTopicId}
          onCurriculumSelect={handleCurriculumSelect}
          onTopicSelect={handleTopicSelect}
          onRefresh={handleRefresh}
          isLoading={curriculaLoading}
          className="h-full"
        />
      </div>
    </main>
  );
}
