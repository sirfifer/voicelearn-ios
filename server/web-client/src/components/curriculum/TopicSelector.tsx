'use client';

import * as React from 'react';
import { ChevronRight, ChevronDown, BookOpen, FileText, Layers } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { ContentNode, Topic as _Topic, NodeType } from '@/types';

// ===== Types =====

export interface TopicSelectorProps {
  topics: ContentNode[];
  selectedTopicId?: string;
  onSelect?: (topic: ContentNode) => void;
  className?: string;
  expandAll?: boolean;
}

// ===== Helpers =====

function getNodeIcon(type: NodeType) {
  switch (type) {
    case 'curriculum':
    case 'unit':
      return Layers;
    case 'module':
    case 'topic':
      return BookOpen;
    case 'lesson':
    case 'section':
    case 'segment':
      return FileText;
    default:
      return FileText;
  }
}

function isSelectable(type: NodeType): boolean {
  return ['topic', 'subtopic', 'lesson'].includes(type);
}

// ===== Topic Node Component =====

interface TopicNodeProps {
  node: ContentNode;
  selectedTopicId?: string;
  onSelect?: (topic: ContentNode) => void;
  level?: number;
  defaultExpanded?: boolean;
}

function TopicNode({
  node,
  selectedTopicId,
  onSelect,
  level = 0,
  defaultExpanded = false,
}: TopicNodeProps) {
  const [isExpanded, setIsExpanded] = React.useState(defaultExpanded);
  const hasChildren = node.children && node.children.length > 0;
  const isSelected = node.id.value === selectedTopicId;
  const canSelect = isSelectable(node.type);
  const Icon = getNodeIcon(node.type);

  const handleToggle = React.useCallback(
    (e: React.MouseEvent) => {
      e.stopPropagation();
      if (hasChildren) {
        setIsExpanded((prev) => !prev);
      }
    },
    [hasChildren]
  );

  const handleSelect = React.useCallback(() => {
    if (canSelect && onSelect) {
      onSelect(node);
    } else if (hasChildren) {
      setIsExpanded((prev) => !prev);
    }
  }, [canSelect, onSelect, node, hasChildren]);

  const handleKeyDown = React.useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        handleSelect();
      } else if (e.key === 'ArrowRight' && hasChildren && !isExpanded) {
        e.preventDefault();
        setIsExpanded(true);
      } else if (e.key === 'ArrowLeft' && hasChildren && isExpanded) {
        e.preventDefault();
        setIsExpanded(false);
      }
    },
    [handleSelect, hasChildren, isExpanded]
  );

  return (
    <div className="topic-node">
      <div
        className={cn(
          'flex items-center gap-2 py-2 px-2 rounded-md transition-colors',
          canSelect && 'cursor-pointer hover:bg-muted',
          isSelected && 'bg-primary/10 text-primary',
          !canSelect && hasChildren && 'cursor-pointer hover:bg-muted/50'
        )}
        style={{ paddingLeft: `${level * 16 + 8}px` }}
        onClick={handleSelect}
        onKeyDown={handleKeyDown}
        tabIndex={0}
        role="treeitem"
        aria-selected={isSelected}
        aria-expanded={hasChildren ? isExpanded : undefined}
      >
        {/* Expand/Collapse Toggle */}
        {hasChildren ? (
          <button
            className="p-0.5 rounded hover:bg-muted-foreground/10"
            onClick={handleToggle}
            aria-label={isExpanded ? 'Collapse' : 'Expand'}
          >
            {isExpanded ? (
              <ChevronDown className="h-4 w-4 text-muted-foreground" />
            ) : (
              <ChevronRight className="h-4 w-4 text-muted-foreground" />
            )}
          </button>
        ) : (
          <span className="w-5" /> // Spacer for alignment
        )}

        {/* Icon */}
        <Icon className={cn('h-4 w-4 flex-shrink-0', isSelected ? 'text-primary' : 'text-muted-foreground')} />

        {/* Title */}
        <span className="text-sm truncate flex-1">{node.title}</span>

        {/* Type badge */}
        <span className="text-[10px] uppercase text-muted-foreground/60 flex-shrink-0">
          {node.type}
        </span>
      </div>

      {/* Children */}
      {hasChildren && isExpanded && (
        <div role="group" className="topic-children">
          {node.children!.map((child) => (
            <TopicNode
              key={child.id.value}
              node={child}
              selectedTopicId={selectedTopicId}
              onSelect={onSelect}
              level={level + 1}
              defaultExpanded={defaultExpanded}
            />
          ))}
        </div>
      )}
    </div>
  );
}

// ===== Topic Selector Component =====

function TopicSelector({
  topics,
  selectedTopicId,
  onSelect,
  className,
  expandAll = false,
}: TopicSelectorProps) {
  if (topics.length === 0) {
    return (
      <div className={cn('flex flex-col items-center justify-center p-8 text-muted-foreground', className)}>
        <BookOpen className="h-8 w-8 mb-2 opacity-30" />
        <p className="text-sm">No topics available</p>
      </div>
    );
  }

  return (
    <div className={cn('topic-selector', className)} role="tree" aria-label="Topic navigation">
      {topics.map((topic) => (
        <TopicNode
          key={topic.id.value}
          node={topic}
          selectedTopicId={selectedTopicId}
          onSelect={onSelect}
          defaultExpanded={expandAll}
        />
      ))}
    </div>
  );
}

export { TopicSelector, TopicNode };
