'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';
import { ZoomIn, ZoomOut, X, Download } from 'lucide-react';
import { Button } from '@/components/ui';

// ===== Types =====

export interface ImageRendererProps {
  src: string;
  alt: string;
  caption?: string;
  className?: string;
  allowZoom?: boolean;
  allowDownload?: boolean;
}

// ===== Image Renderer Component =====

function ImageRenderer({
  src,
  alt,
  caption,
  className,
  allowZoom = true,
  allowDownload = false,
}: ImageRendererProps) {
  const [isZoomed, setIsZoomed] = React.useState(false);
  const [error, setError] = React.useState(false);
  const [isLoading, setIsLoading] = React.useState(true);

  const handleToggleZoom = React.useCallback(() => {
    setIsZoomed((prev) => !prev);
  }, []);

  const handleKeyDown = React.useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === 'Escape' && isZoomed) {
        setIsZoomed(false);
      }
    },
    [isZoomed]
  );

  const handleDownload = React.useCallback(async () => {
    try {
      const response = await fetch(src);
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = alt.replace(/[^a-z0-9]/gi, '_').toLowerCase() || 'image';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
    } catch (e) {
      console.error('Download failed:', e);
    }
  }, [src, alt]);

  if (error) {
    return (
      <div className={cn('flex items-center justify-center p-8 bg-muted rounded-lg', className)}>
        <div className="text-center">
          <p className="text-muted-foreground">Failed to load image</p>
          <p className="text-sm text-muted-foreground/60 mt-1">{alt}</p>
        </div>
      </div>
    );
  }

  return (
    <>
      {/* Main Image Container */}
      <figure className={cn('image-container relative group', className)}>
        {/* Loading Skeleton */}
        {isLoading && (
          <div className="absolute inset-0 bg-muted animate-pulse rounded-lg" />
        )}

        {/* Image */}
        <img
          src={src}
          alt={alt}
          className={cn(
            'max-w-full h-auto rounded-lg transition-opacity duration-300',
            isLoading ? 'opacity-0' : 'opacity-100',
            allowZoom && 'cursor-zoom-in'
          )}
          onClick={allowZoom ? handleToggleZoom : undefined}
          onLoad={() => setIsLoading(false)}
          onError={() => {
            setError(true);
            setIsLoading(false);
          }}
        />

        {/* Controls Overlay */}
        {!isLoading && (allowZoom || allowDownload) && (
          <div className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
            {allowZoom && (
              <Button
                variant="secondary"
                size="icon"
                className="h-8 w-8 bg-background/80 backdrop-blur"
                onClick={handleToggleZoom}
                aria-label="Zoom image"
              >
                <ZoomIn className="h-4 w-4" />
              </Button>
            )}
            {allowDownload && (
              <Button
                variant="secondary"
                size="icon"
                className="h-8 w-8 bg-background/80 backdrop-blur"
                onClick={handleDownload}
                aria-label="Download image"
              >
                <Download className="h-4 w-4" />
              </Button>
            )}
          </div>
        )}

        {/* Caption */}
        {caption && (
          <figcaption className="mt-2 text-sm text-muted-foreground text-center">
            {caption}
          </figcaption>
        )}
      </figure>

      {/* Zoomed Modal */}
      {isZoomed && (
        <div
          className="fixed inset-0 z-50 bg-black/90 flex items-center justify-center p-4"
          onClick={handleToggleZoom}
          onKeyDown={handleKeyDown}
          role="dialog"
          aria-modal="true"
          aria-label={`Zoomed view: ${alt}`}
        >
          {/* Close Button */}
          <Button
            variant="ghost"
            size="icon"
            className="absolute top-4 right-4 text-white hover:bg-white/20"
            onClick={handleToggleZoom}
            aria-label="Close zoomed view"
          >
            <X className="h-6 w-6" />
          </Button>

          {/* Zoom Controls */}
          <Button
            variant="ghost"
            size="icon"
            className="absolute top-4 left-4 text-white hover:bg-white/20"
            onClick={(e) => e.stopPropagation()}
            aria-label="Zoom out"
          >
            <ZoomOut className="h-6 w-6" />
          </Button>

          {/* Zoomed Image */}
          <img
            src={src}
            alt={alt}
            className="max-w-[90vw] max-h-[90vh] object-contain cursor-zoom-out"
            onClick={(e) => {
              e.stopPropagation();
              handleToggleZoom();
            }}
          />
        </div>
      )}
    </>
  );
}

export { ImageRenderer };
