'use client';

import { useState, useEffect, useCallback } from 'react';
import {
  FlaskConical,
  RefreshCw,
  Cpu,
  Mic,
  Volume2,
  Play,
  Square,
  Loader2,
  HardDrive,
  Download,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import type { ModelInfo } from '@/types';
import { getModels, loadModel, unloadModel } from '@/lib/api-client';
import { cn } from '@/lib/utils';
import { ModelPullDialog } from './model-pull-dialog';

export function ModelsPanel() {
  const [models, setModels] = useState<ModelInfo[]>([]);
  const [counts, setCounts] = useState({ llm: 0, stt: 0, tts: 0 });
  const [loading, setLoading] = useState(true);
  const [operatingModels, setOperatingModels] = useState<Set<string>>(new Set());
  const [error, setError] = useState<string | null>(null);
  const [showPullDialog, setShowPullDialog] = useState(false);

  const fetchModels = useCallback(async () => {
    try {
      const response = await getModels();
      setModels(response.models);
      setCounts(response.by_type);
      setError(null);
    } catch (err) {
      console.error('Failed to fetch models:', err);
      setError('Failed to fetch models');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchModels();
    const interval = setInterval(fetchModels, 60000);
    return () => clearInterval(interval);
  }, [fetchModels]);

  const handleLoadModel = async (model: ModelInfo) => {
    if (operatingModels.has(model.id)) return;

    setOperatingModels((prev) => new Set(prev).add(model.id));
    setError(null);

    try {
      await loadModel(model.id);
      // Refresh model list to get updated status
      await fetchModels();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load model');
    } finally {
      setOperatingModels((prev) => {
        const next = new Set(prev);
        next.delete(model.id);
        return next;
      });
    }
  };

  const handleUnloadModel = async (model: ModelInfo) => {
    if (operatingModels.has(model.id)) return;

    setOperatingModels((prev) => new Set(prev).add(model.id));
    setError(null);

    try {
      await unloadModel(model.id);
      // Refresh model list to get updated status
      await fetchModels();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to unload model');
    } finally {
      setOperatingModels((prev) => {
        const next = new Set(prev);
        next.delete(model.id);
        return next;
      });
    }
  };

  const typeStyles: Record<string, { icon: typeof Cpu; color: string; bgColor: string }> = {
    llm: { icon: Cpu, color: 'text-violet-400', bgColor: 'bg-violet-500/10 border-violet-500/30' },
    stt: {
      icon: Mic,
      color: 'text-emerald-400',
      bgColor: 'bg-emerald-500/10 border-emerald-500/30',
    },
    tts: { icon: Volume2, color: 'text-blue-400', bgColor: 'bg-blue-500/10 border-blue-500/30' },
  };

  const getStatusBadgeVariant = (status: string): 'success' | 'warning' | 'default' => {
    switch (status) {
      case 'loaded':
        return 'success';
      case 'loading':
        return 'warning';
      default:
        return 'default';
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-semibold">Available Models</h2>
        <div className="flex gap-2">
          <button
            onClick={fetchModels}
            className="flex items-center gap-2 px-3 py-1.5 text-sm font-medium rounded-lg border border-slate-700 text-slate-300 hover:text-slate-100 hover:bg-slate-700/50 transition-all"
          >
            <RefreshCw className="w-4 h-4" />
            Refresh
          </button>
          <button
            onClick={() => setShowPullDialog(true)}
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg bg-indigo-500 hover:bg-indigo-400 text-white transition-all"
          >
            <Download className="w-4 h-4" />
            Pull Model
          </button>
        </div>
      </div>

      {/* Pull Model Dialog */}
      {showPullDialog && (
        <ModelPullDialog
          onClose={() => setShowPullDialog(false)}
          onComplete={() => fetchModels()}
        />
      )}

      {/* Error Display */}
      {error && (
        <div className="bg-red-500/10 border border-red-500/30 rounded-lg px-4 py-3 text-red-400 text-sm">
          {error}
        </div>
      )}

      {/* Type Filters */}
      <div className="flex gap-4">
        {(['llm', 'stt', 'tts'] as const).map((type) => {
          const style = typeStyles[type];
          const Icon = style.icon;
          return (
            <div
              key={type}
              className={cn('flex items-center gap-2 px-4 py-2 rounded-lg border', style.bgColor)}
            >
              <Icon className={cn('w-5 h-5', style.color)} />
              <span className="font-medium">{counts[type]}</span>
              <span className="text-slate-400 uppercase text-sm">{type}</span>
            </div>
          );
        })}
      </div>

      {/* Models Grid */}
      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
        {loading ? (
          Array.from({ length: 6 }).map((_, i) => (
            <Card key={i}>
              <CardContent className="h-24 flex items-center justify-center">
                <div className="animate-pulse text-slate-500">Loading...</div>
              </CardContent>
            </Card>
          ))
        ) : models.length === 0 ? (
          <div className="col-span-full text-center text-slate-500 py-12">
            <FlaskConical className="w-16 h-16 mx-auto mb-4 opacity-30" />
            <p className="text-lg font-medium">No models available</p>
            <p className="text-sm mt-1">Models will appear when servers are healthy</p>
          </div>
        ) : (
          models.map((model) => {
            const style = typeStyles[model.type] || typeStyles.llm;
            const Icon = style.icon;
            const isOperating = operatingModels.has(model.id);
            const isLoaded = model.status === 'loaded';
            const isLLM = model.type === 'llm';

            return (
              <Card key={model.id} className="hover:border-slate-600/50 transition-all">
                <CardContent className="pt-4">
                  <div className="flex items-start justify-between mb-3">
                    <div className="flex items-center gap-2">
                      <Icon className={cn('w-5 h-5', style.color)} />
                      <h3 className="font-semibold text-slate-100 truncate" title={model.name}>
                        {model.name}
                      </h3>
                    </div>
                    <Badge variant={getStatusBadgeVariant(model.status)}>{model.status}</Badge>
                  </div>

                  <div className="space-y-1 text-sm">
                    <div className="flex justify-between">
                      <span className="text-slate-400">Type</span>
                      <span className="text-slate-200 uppercase">{model.type}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-400">Server</span>
                      <span className="text-slate-200">{model.server_name}</span>
                    </div>
                    {model.parameters && (
                      <div className="flex justify-between">
                        <span className="text-slate-400">Params</span>
                        <span className="text-slate-200">{model.parameters}</span>
                      </div>
                    )}
                    {model.quantization && (
                      <div className="flex justify-between">
                        <span className="text-slate-400">Quant</span>
                        <span className="text-slate-200 font-mono text-xs">
                          {model.quantization}
                        </span>
                      </div>
                    )}
                    {model.size_gb !== undefined && model.size_gb > 0 && (
                      <div className="flex justify-between">
                        <span className="text-slate-400">Size</span>
                        <span className="text-slate-200">{model.size_gb.toFixed(1)} GB</span>
                      </div>
                    )}
                    {isLoaded && model.vram_gb !== undefined && model.vram_gb > 0 && (
                      <div className="flex justify-between items-center">
                        <span className="text-slate-400 flex items-center gap-1">
                          <HardDrive className="w-3 h-3" />
                          VRAM
                        </span>
                        <span className="text-emerald-400 font-medium">
                          {model.vram_gb.toFixed(1)} GB
                        </span>
                      </div>
                    )}
                  </div>

                  {/* Load/Unload buttons for LLM models */}
                  {isLLM && (
                    <div className="mt-4 pt-3 border-t border-slate-700/50">
                      {isLoaded ? (
                        <button
                          onClick={() => handleUnloadModel(model)}
                          disabled={isOperating}
                          className={cn(
                            'w-full flex items-center justify-center gap-2 px-3 py-2 text-sm font-medium rounded-lg transition-all',
                            isOperating
                              ? 'bg-slate-700 text-slate-400 cursor-not-allowed'
                              : 'bg-amber-500/20 text-amber-400 hover:bg-amber-500/30 border border-amber-500/30'
                          )}
                        >
                          {isOperating ? (
                            <>
                              <Loader2 className="w-4 h-4 animate-spin" />
                              Unloading...
                            </>
                          ) : (
                            <>
                              <Square className="w-4 h-4" />
                              Unload
                            </>
                          )}
                        </button>
                      ) : (
                        <button
                          onClick={() => handleLoadModel(model)}
                          disabled={isOperating}
                          className={cn(
                            'w-full flex items-center justify-center gap-2 px-3 py-2 text-sm font-medium rounded-lg transition-all',
                            isOperating
                              ? 'bg-slate-700 text-slate-400 cursor-not-allowed'
                              : 'bg-emerald-500/20 text-emerald-400 hover:bg-emerald-500/30 border border-emerald-500/30'
                          )}
                        >
                          {isOperating ? (
                            <>
                              <Loader2 className="w-4 h-4 animate-spin" />
                              Loading...
                            </>
                          ) : (
                            <>
                              <Play className="w-4 h-4" />
                              Load
                            </>
                          )}
                        </button>
                      )}
                    </div>
                  )}
                </CardContent>
              </Card>
            );
          })
        )}
      </div>
    </div>
  );
}
