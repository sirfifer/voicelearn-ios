'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';
import { ChevronLeft, ChevronRight, Image as ImageIcon } from 'lucide-react';
import { Button } from '@/components/ui';
import { FormulaRenderer } from './FormulaRenderer';
import { MapRenderer, type MapConfig } from './MapRenderer';
import { DiagramRenderer } from './DiagramRenderer';
import { ChartRenderer } from './ChartRenderer';
import { ImageRenderer } from './ImageRenderer';
import type { VisualAsset, FormulaAsset, MapAsset, DiagramAsset, ChartAsset, ImageAsset } from '@/types';

// ===== Types =====

export interface VisualPanelProps {
  assets: VisualAsset[];
  currentIndex?: number;
  onIndexChange?: (index: number) => void;
  className?: string;
  showThumbnails?: boolean;
}

// ===== Asset Viewer Component =====

interface AssetViewerProps {
  asset: VisualAsset;
  className?: string;
}

function AssetViewer({ asset, className }: AssetViewerProps) {
  switch (asset.type) {
    case 'formula':
    case 'equation': {
      const formulaAsset = asset as FormulaAsset;
      return (
        <FormulaRenderer
          latex={formulaAsset.latex}
          displayMode={formulaAsset.displayMode === 'block'}
          semanticMeaning={formulaAsset.semanticMeaning}
          className={className}
        />
      );
    }

    case 'map': {
      const mapAsset = asset as MapAsset;
      const config: MapConfig = {
        center: mapAsset.geography.center,
        zoom: mapAsset.geography.zoom,
        style: mapAsset.mapStyle,
        markers: mapAsset.markers,
        routes: mapAsset.routes,
        regions: mapAsset.regions,
        interactive: mapAsset.interactive,
      };
      return <MapRenderer config={config} className={className} />;
    }

    case 'diagram': {
      const diagramAsset = asset as DiagramAsset;
      return (
        <DiagramRenderer
          source={diagramAsset.sourceCode?.code || ''}
          format={diagramAsset.sourceCode?.format}
          fallbackUrl={diagramAsset.url}
          alt={diagramAsset.alt}
          className={className}
        />
      );
    }

    case 'chart': {
      const chartAsset = asset as ChartAsset;
      return (
        <ChartRenderer
          data={chartAsset.chartData}
          type={chartAsset.chartType}
          title={chartAsset.title}
          className={className}
        />
      );
    }

    case 'image':
    default: {
      // Handles 'image', 'slideImage', 'slideDeck', and any other types
      const imageAsset = asset as ImageAsset;
      return (
        <ImageRenderer
          src={imageAsset.url || ''}
          alt={imageAsset.alt}
          caption={imageAsset.caption}
          className={className}
        />
      );
    }
  }
}

// ===== Thumbnail Component =====

interface ThumbnailProps {
  asset: VisualAsset;
  isActive: boolean;
  onClick: () => void;
}

function Thumbnail({ asset, isActive, onClick }: ThumbnailProps) {
  const getIcon = () => {
    switch (asset.type) {
      case 'formula':
      case 'equation':
        return <span className="text-xs font-mono">fx</span>;
      case 'map':
        return <span className="text-xs">🗺️</span>;
      case 'diagram':
        return <span className="text-xs">📊</span>;
      case 'chart':
        return <span className="text-xs">📈</span>;
      default:
        return <ImageIcon className="h-3 w-3" />;
    }
  };

  return (
    <button
      onClick={onClick}
      className={cn(
        'flex-shrink-0 w-12 h-12 rounded-lg border-2 flex items-center justify-center transition-all',
        isActive
          ? 'border-primary bg-primary/10'
          : 'border-muted bg-muted/50 hover:border-muted-foreground'
      )}
      aria-label={`View ${asset.title || asset.type}`}
      aria-current={isActive ? 'true' : undefined}
    >
      {getIcon()}
    </button>
  );
}

// ===== Visual Panel Component =====

function VisualPanel({
  assets,
  currentIndex = 0,
  onIndexChange,
  className,
  showThumbnails = true,
}: VisualPanelProps) {
  const [internalIndex, setInternalIndex] = React.useState(currentIndex);

  const activeIndex = onIndexChange ? currentIndex : internalIndex;
  const setActiveIndex = onIndexChange || setInternalIndex;

  const currentAsset = assets[activeIndex];
  const hasMultiple = assets.length > 1;

  const handlePrevious = React.useCallback(() => {
    setActiveIndex((activeIndex - 1 + assets.length) % assets.length);
  }, [activeIndex, assets.length, setActiveIndex]);

  const handleNext = React.useCallback(() => {
    setActiveIndex((activeIndex + 1) % assets.length);
  }, [activeIndex, assets.length, setActiveIndex]);

  // Keyboard navigation
  React.useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowLeft') {
        handlePrevious();
      } else if (e.key === 'ArrowRight') {
        handleNext();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handlePrevious, handleNext]);

  // Empty state
  if (assets.length === 0) {
    return (
      <div
        className={cn(
          'flex flex-col items-center justify-center h-full p-8 text-muted-foreground',
          className
        )}
      >
        <ImageIcon className="h-12 w-12 mb-4 opacity-30" />
        <p className="text-sm">No visual assets available</p>
      </div>
    );
  }

  return (
    <div className={cn('flex flex-col h-full', className)}>
      {/* Header with navigation */}
      {hasMultiple && (
        <div className="flex items-center justify-between p-2 border-b">
          <Button variant="ghost" size="icon" onClick={handlePrevious} aria-label="Previous asset">
            <ChevronLeft className="h-4 w-4" />
          </Button>

          <span className="text-sm text-muted-foreground">
            {activeIndex + 1} / {assets.length}
          </span>

          <Button variant="ghost" size="icon" onClick={handleNext} aria-label="Next asset">
            <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
      )}

      {/* Asset title */}
      {currentAsset.title && (
        <div className="px-4 py-2 border-b">
          <h3 className="text-sm font-medium">{currentAsset.title}</h3>
        </div>
      )}

      {/* Main content area */}
      <div className="flex-1 overflow-auto p-4">
        <AssetViewer asset={currentAsset} />
      </div>

      {/* Thumbnail strip */}
      {showThumbnails && hasMultiple && (
        <div className="flex gap-2 p-2 border-t overflow-x-auto">
          {assets.map((asset, index) => (
            <Thumbnail
              key={asset.id}
              asset={asset}
              isActive={index === activeIndex}
              onClick={() => setActiveIndex(index)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

export { VisualPanel, AssetViewer };
