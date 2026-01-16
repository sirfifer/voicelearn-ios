'use client';

import { useState, useRef, useEffect } from 'react';
import { Play, Pause, RotateCcw, Save, Loader2 } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { WaveformDisplay } from './waveform-display';
import { RatingWidget } from './rating-widget';
import type { TTSComparisonVariant, TTSComparisonRating } from '@/types';
import { cn } from '@/lib/utils';

interface VariantPlayerProps {
  variant: TTSComparisonVariant;
  rating?: TTSComparisonRating;
  configName?: string;
  isSelected?: boolean;
  onSelect?: () => void;
  onRate?: (rating: number, notes?: string) => void;
  onSaveAsProfile?: () => void;
}

function VariantPlayer({
  variant,
  rating,
  configName,
  isSelected,
  onSelect,
  onRate,
  onSaveAsProfile,
}: VariantPlayerProps) {
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const [notes, setNotes] = useState(rating?.notes || '');
  const [localRating, setLocalRating] = useState(rating?.rating || 0);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const animationRef = useRef<number | undefined>(undefined);

  const audioUrl = variant.output_file ? `/api/tts/pregen/variants/${variant.id}/audio` : undefined;

  const isReady = variant.status === 'ready';
  const isGenerating = variant.status === 'generating';
  const isFailed = variant.status === 'failed';

  useEffect(() => {
    const updateProgress = () => {
      if (audioRef.current) {
        const current = audioRef.current.currentTime;
        const duration = audioRef.current.duration;
        if (duration > 0) {
          setProgress(current / duration);
        }
      }
      if (isPlaying) {
        animationRef.current = requestAnimationFrame(updateProgress);
      }
    };

    if (isPlaying) {
      animationRef.current = requestAnimationFrame(updateProgress);
    }
    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [isPlaying]);

  useEffect(() => {
    return () => {
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current = null;
      }
    };
  }, []);

  const handlePlayPause = async () => {
    if (!audioUrl || !isReady) return;

    if (isPlaying && audioRef.current) {
      audioRef.current.pause();
      setIsPlaying(false);
      return;
    }

    try {
      if (!audioRef.current) {
        audioRef.current = new Audio(audioUrl);
        audioRef.current.onended = () => {
          setIsPlaying(false);
          setProgress(0);
        };
      }

      await audioRef.current.play();
      setIsPlaying(true);
    } catch {
      setIsPlaying(false);
    }
  };

  const handleRestart = () => {
    if (audioRef.current) {
      audioRef.current.currentTime = 0;
      setProgress(0);
    }
  };

  const handleWaveformClick = (newProgress: number) => {
    if (audioRef.current) {
      const duration = audioRef.current.duration;
      if (duration > 0) {
        audioRef.current.currentTime = newProgress * duration;
        setProgress(newProgress);
      }
    }
  };

  const handleRatingChange = (value: number) => {
    setLocalRating(value);
    onRate?.(value, notes);
  };

  const handleNotesBlur = () => {
    if (localRating > 0) {
      onRate?.(localRating, notes);
    }
  };

  return (
    <Card
      className={cn(
        'transition-all',
        isSelected && 'ring-2 ring-primary',
        onSelect && 'cursor-pointer hover:border-primary/50'
      )}
      onClick={onSelect}
    >
      <CardHeader className="pb-2">
        <div className="flex items-center justify-between">
          <CardTitle className="text-sm font-medium">
            {configName || `Config ${variant.config_index + 1}`}
          </CardTitle>
          <div className="flex items-center gap-2">
            {isGenerating && (
              <Badge variant="warning" className="gap-1">
                <Loader2 className="w-3 h-3 animate-spin" />
                Generating
              </Badge>
            )}
            {isFailed && <Badge variant="error">Failed</Badge>}
            {isReady && (
              <Badge variant="outline" className="text-green-400 border-green-400/30">
                Ready
              </Badge>
            )}
          </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        {/* Waveform */}
        <WaveformDisplay
          audioUrl={isReady ? audioUrl : undefined}
          progress={progress}
          height={48}
          onClick={isReady ? handleWaveformClick : undefined}
          className={cn(!isReady && 'opacity-50')}
        />

        {/* Controls */}
        <div className="flex items-center gap-2">
          <Button
            size="sm"
            variant="outline"
            onClick={(e) => {
              e.stopPropagation();
              handlePlayPause();
            }}
            disabled={!isReady}
          >
            {isPlaying ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
          </Button>
          <Button
            size="sm"
            variant="ghost"
            onClick={(e) => {
              e.stopPropagation();
              handleRestart();
            }}
            disabled={!isReady}
          >
            <RotateCcw className="w-4 h-4" />
          </Button>
          {variant.duration_seconds && (
            <span className="text-xs text-muted-foreground ml-auto">
              {variant.duration_seconds.toFixed(1)}s
            </span>
          )}
        </div>

        {/* Rating */}
        <div className="space-y-2">
          <RatingWidget rating={localRating} onChange={handleRatingChange} size="md" />
          <textarea
            placeholder="Add notes (optional)..."
            value={notes}
            onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setNotes(e.target.value)}
            onBlur={handleNotesBlur}
            onClick={(e: React.MouseEvent) => e.stopPropagation()}
            rows={2}
            className="w-full text-sm resize-none bg-slate-800 border border-slate-600 rounded-md px-3 py-2 text-slate-100 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>

        {/* Save as Profile button */}
        {onSaveAsProfile && isReady && localRating >= 4 && (
          <Button
            size="sm"
            variant="outline"
            className="w-full"
            onClick={(e: React.MouseEvent) => {
              e.stopPropagation();
              onSaveAsProfile();
            }}
          >
            <Save className="w-4 h-4 mr-2" />
            Save as Profile
          </Button>
        )}

        {/* Error message */}
        {isFailed && variant.last_error && (
          <p className="text-xs text-destructive">{variant.last_error}</p>
        )}
      </CardContent>
    </Card>
  );
}

interface ComparisonPlayerProps {
  variants: TTSComparisonVariant[];
  ratings: Record<string, TTSComparisonRating>;
  configNames?: string[];
  sampleText?: string;
  onRate?: (variantId: string, rating: number, notes?: string) => void;
  onSaveAsProfile?: (variantId: string) => void;
}

export function ComparisonPlayer({
  variants,
  ratings,
  configNames,
  sampleText,
  onRate,
  onSaveAsProfile,
}: ComparisonPlayerProps) {
  const [selectedVariantId, setSelectedVariantId] = useState<string | null>(null);

  // Group variants by sample
  const sampleVariants = variants.filter((v) => v.sample_index === variants[0]?.sample_index);

  return (
    <div className="space-y-4">
      {sampleText && (
        <div className="p-3 bg-muted/50 rounded-lg">
          <p className="text-sm text-muted-foreground mb-1">Sample text:</p>
          <p className="text-sm font-medium">&ldquo;{sampleText}&rdquo;</p>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {sampleVariants.map((variant) => (
          <VariantPlayer
            key={variant.id}
            variant={variant}
            rating={ratings[variant.id]}
            configName={configNames?.[variant.config_index]}
            isSelected={selectedVariantId === variant.id}
            onSelect={() => setSelectedVariantId(variant.id)}
            onRate={(rating, notes) => onRate?.(variant.id, rating, notes)}
            onSaveAsProfile={onSaveAsProfile ? () => onSaveAsProfile(variant.id) : undefined}
          />
        ))}
      </div>
    </div>
  );
}
