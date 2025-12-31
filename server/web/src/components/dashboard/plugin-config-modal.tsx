'use client';

import { useState, useEffect } from 'react';
import { X, Save, TestTube, Loader2 } from 'lucide-react';
import { Badge } from '@/components/ui/badge';

interface SchemaField {
  name: string;
  type: 'string' | 'number' | 'boolean' | 'select';
  label: string;
  description?: string;
  required?: boolean;
  default?: string | number | boolean;
  options?: Array<{ value: string; label: string }>;
  placeholder?: string;
}

interface PluginSchema {
  fields: SchemaField[];
}

interface PluginConfigModalProps {
  pluginId: string;
  pluginName: string;
  isOpen: boolean;
  onClose: () => void;
  onSave: () => void;
}

async function getPluginSchema(pluginId: string): Promise<PluginSchema> {
  const response = await fetch(`/api/plugins/${pluginId}/schema`);
  if (!response.ok) {
    throw new Error('Failed to fetch plugin schema');
  }
  const data = await response.json();
  return data.schema;
}

async function getPluginConfig(pluginId: string): Promise<Record<string, unknown>> {
  const response = await fetch(`/api/plugins/${pluginId}`);
  if (!response.ok) {
    throw new Error('Failed to fetch plugin config');
  }
  const data = await response.json();
  return data.plugin?.settings || {};
}

async function savePluginConfig(pluginId: string, settings: Record<string, unknown>): Promise<void> {
  const response = await fetch(`/api/plugins/${pluginId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ settings }),
  });
  if (!response.ok) {
    throw new Error('Failed to save plugin config');
  }
}

async function testPluginConfig(pluginId: string, settings: Record<string, unknown>): Promise<{ success: boolean; message?: string }> {
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

export function PluginConfigModal({ pluginId, pluginName, isOpen, onClose, onSave }: PluginConfigModalProps) {
  const [schema, setSchema] = useState<PluginSchema | null>(null);
  const [values, setValues] = useState<Record<string, unknown>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<{ success: boolean; message?: string } | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!isOpen) return;

    const loadData = async () => {
      setLoading(true);
      setError(null);
      setTestResult(null);
      try {
        const [schemaData, configData] = await Promise.all([
          getPluginSchema(pluginId),
          getPluginConfig(pluginId),
        ]);
        setSchema(schemaData);

        // Initialize values with defaults and existing config
        const initialValues: Record<string, unknown> = {};
        schemaData.fields.forEach(field => {
          initialValues[field.name] = configData[field.name] ?? field.default ?? '';
        });
        setValues(initialValues);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load plugin configuration');
      } finally {
        setLoading(false);
      }
    };

    loadData();
  }, [isOpen, pluginId]);

  const handleSave = async () => {
    setSaving(true);
    setError(null);
    try {
      await savePluginConfig(pluginId, values);
      onSave();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save configuration');
    } finally {
      setSaving(false);
    }
  };

  const handleTest = async () => {
    setTesting(true);
    setTestResult(null);
    try {
      const result = await testPluginConfig(pluginId, values);
      setTestResult(result);
    } catch (err) {
      setTestResult({ success: false, message: err instanceof Error ? err.message : 'Test failed' });
    } finally {
      setTesting(false);
    }
  };

  const updateValue = (name: string, value: unknown) => {
    setValues(prev => ({ ...prev, [name]: value }));
    setTestResult(null);
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/60" onClick={onClose} />

      {/* Modal */}
      <div className="relative bg-slate-900 border border-slate-700 rounded-lg shadow-xl w-full max-w-lg max-h-[90vh] overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-700">
          <h2 className="text-lg font-medium text-slate-100">Configure {pluginName}</h2>
          <button
            onClick={onClose}
            className="p-1 text-slate-400 hover:text-slate-200 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto max-h-[calc(90vh-140px)]">
          {loading ? (
            <div className="flex items-center justify-center py-8">
              <div className="animate-spin w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full" />
            </div>
          ) : error ? (
            <div className="p-4 bg-red-500/10 border border-red-500/30 rounded-md text-red-400">
              {error}
            </div>
          ) : schema && schema.fields.length > 0 ? (
            <div className="space-y-4">
              {schema.fields.map(field => (
                <div key={field.name}>
                  <label className="block text-sm font-medium text-slate-300 mb-1">
                    {field.label}
                    {field.required && <span className="text-red-400 ml-1">*</span>}
                  </label>

                  {field.type === 'boolean' ? (
                    <button
                      type="button"
                      onClick={() => updateValue(field.name, !values[field.name])}
                      className={`relative w-12 h-6 rounded-full transition-colors ${
                        values[field.name] ? 'bg-emerald-500' : 'bg-slate-700'
                      }`}
                    >
                      <span
                        className={`absolute top-1 w-4 h-4 rounded-full bg-white transition-transform ${
                          values[field.name] ? 'left-7' : 'left-1'
                        }`}
                      />
                    </button>
                  ) : field.type === 'select' && field.options ? (
                    <select
                      value={String(values[field.name] || '')}
                      onChange={(e) => updateValue(field.name, e.target.value)}
                      className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-md text-slate-100 focus:outline-none focus:ring-2 focus:ring-orange-500/50"
                    >
                      <option value="">Select...</option>
                      {field.options.map(opt => (
                        <option key={opt.value} value={opt.value}>{opt.label}</option>
                      ))}
                    </select>
                  ) : field.type === 'number' ? (
                    <input
                      type="number"
                      value={String(values[field.name] || '')}
                      onChange={(e) => updateValue(field.name, e.target.valueAsNumber || 0)}
                      placeholder={field.placeholder}
                      className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-md text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-orange-500/50"
                    />
                  ) : (
                    <input
                      type="text"
                      value={String(values[field.name] || '')}
                      onChange={(e) => updateValue(field.name, e.target.value)}
                      placeholder={field.placeholder}
                      className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-md text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-orange-500/50"
                    />
                  )}

                  {field.description && (
                    <p className="text-xs text-slate-500 mt-1">{field.description}</p>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <p className="text-slate-500 text-center py-8">No configuration options available</p>
          )}

          {/* Test Result */}
          {testResult && (
            <div className={`mt-4 p-4 rounded-md ${
              testResult.success
                ? 'bg-emerald-500/10 border border-emerald-500/30'
                : 'bg-red-500/10 border border-red-500/30'
            }`}>
              <div className="flex items-center gap-2">
                <Badge className={testResult.success
                  ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                  : 'bg-red-500/20 text-red-400 border-red-500/30'
                }>
                  {testResult.success ? 'Success' : 'Failed'}
                </Badge>
                {testResult.message && (
                  <span className={testResult.success ? 'text-emerald-400' : 'text-red-400'}>
                    {testResult.message}
                  </span>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-6 py-4 border-t border-slate-700 bg-slate-900/50">
          <button
            onClick={handleTest}
            disabled={testing || loading}
            className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-slate-300 bg-slate-800 hover:bg-slate-700 rounded-md transition-colors disabled:opacity-50"
          >
            {testing ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <TestTube className="w-4 h-4" />
            )}
            Test Connection
          </button>

          <div className="flex items-center gap-2">
            <button
              onClick={onClose}
              className="px-4 py-2 text-sm font-medium text-slate-400 hover:text-slate-200 transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={saving || loading}
              className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-orange-500 hover:bg-orange-600 rounded-md transition-colors disabled:opacity-50"
            >
              {saving ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <Save className="w-4 h-4" />
              )}
              Save
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
