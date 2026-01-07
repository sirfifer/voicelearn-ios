'use client';

import * as React from 'react';
import { BookOpen, Clock, GraduationCap, ChevronRight } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui';
import type { CurriculumSummary } from '@/types';

// ===== Types =====

export interface CurriculumCardProps {
  curriculum: CurriculumSummary;
  onClick?: (curriculum: CurriculumSummary) => void;
  isSelected?: boolean;
  className?: string;
}

// ===== Helpers =====

function _getDifficultyColor(difficulty?: string): string {
  switch (difficulty) {
    case 'beginner':
      return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-100';
    case 'intermediate':
      return 'bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-100';
    case 'advanced':
      return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-100';
    default:
      return 'bg-muted text-muted-foreground';
  }
}

function formatDate(dateString: string): string {
  return new Date(dateString).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

// ===== Curriculum Card Component =====

function CurriculumCard({ curriculum, onClick, isSelected, className }: CurriculumCardProps) {
  const handleClick = React.useCallback(() => {
    onClick?.(curriculum);
  }, [curriculum, onClick]);

  const handleKeyDown = React.useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        onClick?.(curriculum);
      }
    },
    [curriculum, onClick]
  );

  return (
    <Card
      className={cn(
        'cursor-pointer transition-all hover:shadow-md',
        isSelected && 'ring-2 ring-primary',
        onClick && 'hover:border-primary/50',
        className
      )}
      onClick={handleClick}
      onKeyDown={handleKeyDown}
      tabIndex={onClick ? 0 : undefined}
      role={onClick ? 'button' : undefined}
      aria-pressed={isSelected}
      aria-label={`Select curriculum: ${curriculum.title}`}
    >
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between gap-2">
          <div className="flex-1 min-w-0">
            <CardTitle className="text-base truncate">{curriculum.title}</CardTitle>
            {curriculum.author && (
              <CardDescription className="truncate">by {curriculum.author}</CardDescription>
            )}
          </div>
          {onClick && (
            <ChevronRight className="h-5 w-5 text-muted-foreground flex-shrink-0 mt-0.5" />
          )}
        </div>
      </CardHeader>

      <CardContent className="pt-0">
        {curriculum.description && (
          <p className="text-sm text-muted-foreground line-clamp-2 mb-3">
            {curriculum.description}
          </p>
        )}

        <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
          {/* Topics count */}
          <div className="flex items-center gap-1">
            <BookOpen className="h-3.5 w-3.5" />
            <span>
              {curriculum.topics_count} topic{curriculum.topics_count !== 1 ? 's' : ''}
            </span>
          </div>

          {/* Language */}
          <div className="flex items-center gap-1">
            <GraduationCap className="h-3.5 w-3.5" />
            <span className="uppercase">{curriculum.language}</span>
          </div>

          {/* Updated date */}
          <div className="flex items-center gap-1">
            <Clock className="h-3.5 w-3.5" />
            <span>{formatDate(curriculum.updated_at)}</span>
          </div>
        </div>

        {/* Status badge */}
        <div className="mt-3">
          <span
            className={cn(
              'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium',
              curriculum.status === 'published'
                ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-100'
                : curriculum.status === 'draft'
                  ? 'bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-100'
                  : 'bg-muted text-muted-foreground'
            )}
          >
            {curriculum.status}
          </span>
        </div>
      </CardContent>
    </Card>
  );
}

export { CurriculumCard };
