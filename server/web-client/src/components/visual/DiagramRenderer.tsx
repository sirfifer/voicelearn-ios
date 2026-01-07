'use client';

import * as React from 'react';
import mermaid from 'mermaid';
import { cn } from '@/lib/utils';

// ===== Types =====

export interface DiagramRendererProps {
  source: string;
  format?: 'mermaid' | 'graphviz' | 'plantuml' | 'd2';
  fallbackUrl?: string;
  className?: string;
  alt?: string;
}

// ===== Initialize Mermaid =====

let mermaidInitialized = false;

function initMermaid() {
  if (mermaidInitialized) return;

  mermaid.initialize({
    startOnLoad: false,
    theme: 'neutral',
    securityLevel: 'strict',
    fontFamily: 'inherit',
    logLevel: 'error',
    flowchart: {
      htmlLabels: true,
      useMaxWidth: true,
    },
  });

  mermaidInitialized = true;
}

// ===== Diagram Renderer Component =====

function DiagramRenderer({
  source,
  format = 'mermaid',
  fallbackUrl,
  className,
  alt = 'Diagram',
}: DiagramRendererProps) {
  const containerRef = React.useRef<HTMLDivElement>(null);
  const [error, setError] = React.useState<string | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);
  const [svgContent, setSvgContent] = React.useState<string | null>(null);

  React.useEffect(() => {
    const renderDiagram = async () => {
      if (format !== 'mermaid') {
        // For non-mermaid formats, we can't render client-side
        setIsLoading(false);
        return;
      }

      if (!source) {
        setError('No diagram source provided');
        setIsLoading(false);
        return;
      }

      try {
        initMermaid();

        const id = `mermaid-${Date.now()}-${Math.random().toString(36).substring(7)}`;
        const { svg } = await mermaid.render(id, source);
        setSvgContent(svg);
        setError(null);
      } catch (e) {
        console.error('Mermaid render error:', e);
        setError(e instanceof Error ? e.message : 'Failed to render diagram');
      } finally {
        setIsLoading(false);
      }
    };

    renderDiagram();
  }, [source, format]);

  // Loading state
  if (isLoading) {
    return (
      <div className={cn('flex items-center justify-center p-8', className)}>
        <div className="animate-pulse text-muted-foreground">Loading diagram...</div>
      </div>
    );
  }

  // Non-mermaid format or error with fallback
  if (format !== 'mermaid' || (error && fallbackUrl)) {
    return (
      <div className={cn('flex justify-center', className)}>
        <img
          src={fallbackUrl || ''}
          alt={alt}
          className="max-w-full h-auto rounded-lg"
          onError={() => setError('Failed to load diagram image')}
        />
      </div>
    );
  }

  // Error without fallback
  if (error) {
    return (
      <div className={cn('text-destructive text-sm p-4 bg-destructive/10 rounded-md', className)}>
        <p className="font-medium">Diagram error</p>
        <p className="text-xs mt-1">{error}</p>
        <details className="mt-2">
          <summary className="text-xs cursor-pointer">View source</summary>
          <pre className="mt-2 text-xs bg-muted p-2 rounded overflow-x-auto whitespace-pre-wrap">
            {source}
          </pre>
        </details>
      </div>
    );
  }

  // Rendered SVG
  return (
    <div
      ref={containerRef}
      className={cn('flex justify-center diagram-container', className)}
      role="img"
      aria-label={alt}
      dangerouslySetInnerHTML={{ __html: svgContent || '' }}
    />
  );
}

export { DiagramRenderer };
