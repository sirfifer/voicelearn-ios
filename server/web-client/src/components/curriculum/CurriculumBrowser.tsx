'use client';

import * as React from 'react';
import { Search, Filter as _Filter, RefreshCw, BookOpen } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Input, Button, Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui';
import { CurriculumCard } from './CurriculumCard';
import { TopicSelector } from './TopicSelector';
import type { CurriculumSummary, ContentNode, Curriculum } from '@/types';

// ===== Types =====

export interface CurriculumBrowserProps {
  curricula: CurriculumSummary[];
  selectedCurriculum?: Curriculum | null;
  selectedTopicId?: string;
  onCurriculumSelect?: (curriculum: CurriculumSummary) => void;
  onTopicSelect?: (topic: ContentNode) => void;
  onRefresh?: () => void;
  isLoading?: boolean;
  className?: string;
}

// ===== Curriculum Browser Component =====

function CurriculumBrowser({
  curricula,
  selectedCurriculum,
  selectedTopicId,
  onCurriculumSelect,
  onTopicSelect,
  onRefresh,
  isLoading = false,
  className,
}: CurriculumBrowserProps) {
  const [searchQuery, setSearchQuery] = React.useState('');
  const [statusFilter, setStatusFilter] = React.useState<'all' | 'published' | 'draft'>('all');

  // Filter curricula based on search and status
  const filteredCurricula = React.useMemo(() => {
    return curricula.filter((c) => {
      const matchesSearch =
        searchQuery === '' ||
        c.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        c.description?.toLowerCase().includes(searchQuery.toLowerCase());

      const matchesStatus = statusFilter === 'all' || c.status === statusFilter;

      return matchesSearch && matchesStatus;
    });
  }, [curricula, searchQuery, statusFilter]);

  // Handle search input
  const handleSearchChange = React.useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    setSearchQuery(e.target.value);
  }, []);

  // Render curriculum list
  const renderCurriculumList = () => {
    if (isLoading) {
      return (
        <div className="flex items-center justify-center p-8">
          <RefreshCw className="h-6 w-6 animate-spin text-muted-foreground" />
        </div>
      );
    }

    if (filteredCurricula.length === 0) {
      return (
        <div className="flex flex-col items-center justify-center p-8 text-muted-foreground">
          <BookOpen className="h-12 w-12 mb-4 opacity-30" />
          <p className="text-sm">
            {searchQuery ? 'No curricula match your search' : 'No curricula available'}
          </p>
        </div>
      );
    }

    return (
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-1">
        {filteredCurricula.map((curriculum) => (
          <CurriculumCard
            key={curriculum.id}
            curriculum={curriculum}
            onClick={onCurriculumSelect}
            isSelected={selectedCurriculum?.id === curriculum.id}
          />
        ))}
      </div>
    );
  };

  // Render topic browser for selected curriculum
  const renderTopicBrowser = () => {
    if (!selectedCurriculum) {
      return (
        <div className="flex flex-col items-center justify-center h-full p-8 text-muted-foreground">
          <BookOpen className="h-12 w-12 mb-4 opacity-30" />
          <p className="text-sm text-center">Select a curriculum to browse topics</p>
        </div>
      );
    }

    return (
      <div className="flex flex-col h-full">
        {/* Curriculum header */}
        <div className="p-4 border-b">
          <h3 className="font-semibold">{selectedCurriculum.title}</h3>
          {selectedCurriculum.description && (
            <p className="text-sm text-muted-foreground mt-1 line-clamp-2">
              {selectedCurriculum.description}
            </p>
          )}
        </div>

        {/* Topic tree */}
        <div className="flex-1 overflow-auto p-2">
          <TopicSelector
            topics={selectedCurriculum.topics || []}
            selectedTopicId={selectedTopicId}
            onSelect={onTopicSelect}
          />
        </div>
      </div>
    );
  };

  return (
    <div className={cn('flex flex-col h-full', className)}>
      <Tabs defaultValue="curricula" className="flex flex-col h-full">
        {/* Header with tabs */}
        <div className="border-b p-2">
          <TabsList className="w-full">
            <TabsTrigger value="curricula" className="flex-1">
              Curricula
            </TabsTrigger>
            <TabsTrigger value="topics" className="flex-1" disabled={!selectedCurriculum}>
              Topics
            </TabsTrigger>
          </TabsList>
        </div>

        {/* Curricula Tab */}
        <TabsContent value="curricula" className="flex-1 flex flex-col m-0">
          {/* Search and filters */}
          <div className="p-4 border-b space-y-3">
            <div className="flex gap-2">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  type="search"
                  placeholder="Search curricula..."
                  value={searchQuery}
                  onChange={handleSearchChange}
                  className="pl-9"
                />
              </div>
              {onRefresh && (
                <Button
                  variant="outline"
                  size="icon"
                  onClick={onRefresh}
                  disabled={isLoading}
                  aria-label="Refresh curricula"
                >
                  <RefreshCw className={cn('h-4 w-4', isLoading && 'animate-spin')} />
                </Button>
              )}
            </div>

            {/* Status filter */}
            <div className="flex gap-2">
              {(['all', 'published', 'draft'] as const).map((status) => (
                <Button
                  key={status}
                  variant={statusFilter === status ? 'secondary' : 'ghost'}
                  size="sm"
                  onClick={() => setStatusFilter(status)}
                  className="capitalize"
                >
                  {status}
                </Button>
              ))}
            </div>
          </div>

          {/* Curriculum list */}
          <div className="flex-1 overflow-auto p-4">{renderCurriculumList()}</div>
        </TabsContent>

        {/* Topics Tab */}
        <TabsContent value="topics" className="flex-1 m-0 overflow-hidden">
          {renderTopicBrowser()}
        </TabsContent>
      </Tabs>
    </div>
  );
}

export { CurriculumBrowser };
