'use client';

import { useState, useEffect, useCallback } from 'react';
import { Puzzle, Check, X, Settings, TestTube, RefreshCw, AlertTriangle } from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { PluginConfigModal } from './plugin-config-modal';

interface PluginApiResponse {
  plugin_id: string;
  name: string;
  description: string;
  version: string;
  plugin_type: string;
  enabled: boolean;
  settings?: Record<string, unknown>;
  error?: string;
}

interface Plugin {
  id: string;
  name: string;
  description: string;
  version: string;
  type: 'source' | 'parser' | 'enricher';
  enabled: boolean;
  configured: boolean;
  hasSettings: boolean;
  error?: string;
}

function mapApiPlugin(p: PluginApiResponse): Plugin {
  return {
    id: p.plugin_id,
    name: p.name,
    description: p.description,
    version: p.version,
    type: p.plugin_type === 'sources' ? 'source' : p.plugin_type as Plugin['type'],
    enabled: p.enabled,
    configured: p.settings ? Object.keys(p.settings).length > 0 : false,
    hasSettings: true, // Assume all plugins can have settings
    error: p.error,
  };
}

interface PluginsResponse {
  success: boolean;
  plugins: PluginApiResponse[];
  first_run?: boolean;
  error?: string;
}

// API functions for plugins
async function getPlugins(): Promise<PluginsResponse> {
  const response = await fetch('/api/plugins');
  if (!response.ok) {
    throw new Error('Failed to fetch plugins');
  }
  return response.json();
}

async function enablePlugin(pluginId: string): Promise<void> {
  const response = await fetch(`/api/plugins/${pluginId}/enable`, { method: 'POST' });
  if (!response.ok) {
    throw new Error('Failed to enable plugin');
  }
}

async function disablePlugin(pluginId: string): Promise<void> {
  const response = await fetch(`/api/plugins/${pluginId}/disable`, { method: 'POST' });
  if (!response.ok) {
    throw new Error('Failed to disable plugin');
  }
}

async function testPlugin(pluginId: string, settings: Record<string, unknown>): Promise<{ success: boolean; message?: string }> {
  const response = await fetch(`/api/plugins/${pluginId}/test`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ settings }),
  });
  if (!response.ok) {
    throw new Error('Failed to test plugin');
  }
  return response.json();
}

export function PluginsPanel() {
  const [plugins, setPlugins] = useState<Plugin[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [firstRunNeeded, setFirstRunNeeded] = useState(false);
  const [testingPlugin, setTestingPlugin] = useState<string | null>(null);
  const [configuringPlugin, setConfiguringPlugin] = useState<Plugin | null>(null);

  const fetchPlugins = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getPlugins();
      setPlugins(data.plugins.map(mapApiPlugin));
      setFirstRunNeeded(data.first_run || false);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load plugins');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchPlugins();
  }, [fetchPlugins]);

  const handleToggle = async (plugin: Plugin) => {
    try {
      if (plugin.enabled) {
        await disablePlugin(plugin.id);
      } else {
        await enablePlugin(plugin.id);
      }
      await fetchPlugins();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to toggle plugin');
    }
  };

  const handleTest = async (plugin: Plugin) => {
    setTestingPlugin(plugin.id);
    try {
      const result = await testPlugin(plugin.id, {});
      if (result.success) {
        alert('Plugin test successful!');
      } else {
        alert(`Plugin test failed: ${result.message || 'Unknown error'}`);
      }
    } catch (err) {
      alert(`Plugin test failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setTestingPlugin(null);
    }
  };

  const getTypeColor = (type: string) => {
    switch (type) {
      case 'source':
        return 'bg-blue-500/20 text-blue-400 border-blue-500/30';
      case 'parser':
        return 'bg-violet-500/20 text-violet-400 border-violet-500/30';
      case 'enricher':
        return 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30';
      default:
        return 'bg-slate-500/20 text-slate-400 border-slate-500/30';
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-white flex items-center gap-2">
            <Puzzle className="w-6 h-6 text-orange-400" />
            Plugins
          </h2>
          <p className="text-slate-400 mt-1">
            Manage curriculum import plugins and enrichers
          </p>
        </div>

        <button
          onClick={fetchPlugins}
          className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-slate-300 bg-slate-800 hover:bg-slate-700 rounded-md transition-colors"
        >
          <RefreshCw className="w-4 h-4" />
          Refresh
        </button>
      </div>

      {/* First Run Warning */}
      {firstRunNeeded && (
        <div className="p-4 bg-amber-500/10 border border-amber-500/30 rounded-md flex items-start gap-3">
          <AlertTriangle className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="font-medium text-amber-300">First-time Setup Required</h3>
            <p className="text-sm text-amber-400/80 mt-1">
              Please enable and configure at least one source plugin to start importing curricula.
            </p>
          </div>
        </div>
      )}

      {/* Error Message */}
      {error && (
        <div className="p-4 bg-red-500/10 border border-red-500/30 rounded-md text-red-400">
          {error}
        </div>
      )}

      {/* Plugins Grid */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full" />
        </div>
      ) : plugins.length === 0 ? (
        <Card className="bg-slate-900/50 border-slate-800">
          <CardContent className="flex flex-col items-center justify-center py-12 text-center">
            <Puzzle className="w-12 h-12 text-slate-600 mb-4" />
            <h3 className="text-lg font-medium text-slate-300 mb-2">No plugins found</h3>
            <p className="text-slate-500 max-w-md">
              Plugins are discovered automatically from the plugins directory.
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {plugins.map((plugin) => (
            <Card
              key={plugin.id}
              className={`bg-slate-900/50 border-slate-800 transition-colors ${
                plugin.enabled ? 'border-l-2 border-l-emerald-500' : ''
              }`}
            >
              <CardHeader className="pb-2">
                <div className="flex items-start justify-between gap-2">
                  <div className="flex-1">
                    <CardTitle className="text-lg font-medium text-slate-100">
                      {plugin.name}
                    </CardTitle>
                    <div className="flex items-center gap-2 mt-1">
                      <Badge className={getTypeColor(plugin.type)}>
                        {plugin.type}
                      </Badge>
                      <span className="text-xs text-slate-500">v{plugin.version}</span>
                    </div>
                  </div>

                  {/* Enable/Disable Toggle */}
                  <button
                    onClick={() => handleToggle(plugin)}
                    className={`relative w-12 h-6 rounded-full transition-colors ${
                      plugin.enabled ? 'bg-emerald-500' : 'bg-slate-700'
                    }`}
                  >
                    <span
                      className={`absolute top-1 w-4 h-4 rounded-full bg-white transition-transform ${
                        plugin.enabled ? 'left-7' : 'left-1'
                      }`}
                    />
                  </button>
                </div>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-slate-400 line-clamp-2 mb-4">
                  {plugin.description}
                </p>

                {/* Plugin Status */}
                <div className="flex items-center gap-2 mb-4">
                  {plugin.enabled ? (
                    <Badge className="bg-emerald-500/20 text-emerald-400 border-emerald-500/30">
                      <Check className="w-3 h-3 mr-1" />
                      Enabled
                    </Badge>
                  ) : (
                    <Badge className="bg-slate-700/50 text-slate-400 border-slate-600">
                      <X className="w-3 h-3 mr-1" />
                      Disabled
                    </Badge>
                  )}

                  {plugin.configured ? (
                    <Badge className="bg-blue-500/20 text-blue-400 border-blue-500/30">
                      Configured
                    </Badge>
                  ) : plugin.hasSettings ? (
                    <Badge className="bg-amber-500/20 text-amber-400 border-amber-500/30">
                      Needs Config
                    </Badge>
                  ) : null}
                </div>

                {/* Plugin Error */}
                {plugin.error && (
                  <div className="text-sm text-red-400 bg-red-500/10 p-2 rounded mb-4">
                    {plugin.error}
                  </div>
                )}

                {/* Actions */}
                <div className="flex items-center gap-2 pt-2 border-t border-slate-800">
                  {plugin.hasSettings && (
                    <button
                      className="flex items-center gap-1.5 text-sm text-slate-400 hover:text-slate-200 transition-colors"
                      onClick={() => setConfiguringPlugin(plugin)}
                    >
                      <Settings className="w-4 h-4" />
                      Configure
                    </button>
                  )}

                  {plugin.enabled && (
                    <button
                      onClick={() => handleTest(plugin)}
                      disabled={testingPlugin === plugin.id}
                      className="flex items-center gap-1.5 text-sm text-slate-400 hover:text-slate-200 transition-colors disabled:opacity-50"
                    >
                      <TestTube className="w-4 h-4" />
                      {testingPlugin === plugin.id ? 'Testing...' : 'Test'}
                    </button>
                  )}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Configuration Modal */}
      {configuringPlugin && (
        <PluginConfigModal
          pluginId={configuringPlugin.id}
          pluginName={configuringPlugin.name}
          isOpen={true}
          onClose={() => setConfiguringPlugin(null)}
          onSave={() => fetchPlugins()}
        />
      )}
    </div>
  );
}
