'use client';

import { useState, useEffect, useCallback } from 'react';
import {
  Settings,
  Plus,
  Copy,
  Trash2,
  Save,
  X,
  Check,
  RefreshCw,
  Sliders,
  Clock,
  AlertTriangle,
  ChevronDown,
  ChevronUp,
  Zap,
  Lock,
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import {
  getPowerModes,
  setIdleConfig,
  createProfile,
  updateProfile,
  deleteProfile,
  duplicateProfile,
} from '@/lib/api-client';
import type { PowerMode, PowerModesResponse, CreateProfileRequest } from '@/types';
import { formatDuration } from '@/lib/utils';

// Threshold presets for quick selection
const THRESHOLD_PRESETS = {
  '10s': 10,
  '30s': 30,
  '1m': 60,
  '2m': 120,
  '5m': 300,
  '10m': 600,
  '15m': 900,
  '30m': 1800,
  '1h': 3600,
  '2h': 7200,
  '4h': 14400,
  'never': 9999999,
};

interface ThresholdEditorProps {
  label: string;
  description: string;
  value: number;
  onChange: (value: number) => void;
  disabled?: boolean;
}

function ThresholdEditor({ label, description, value, onChange, disabled }: ThresholdEditorProps) {
  const [isCustom, setIsCustom] = useState(false);
  const [customMinutes, setCustomMinutes] = useState(Math.floor(value / 60));

  // Find matching preset or mark as custom
  const matchingPreset = Object.entries(THRESHOLD_PRESETS).find(([, v]) => v === value)?.[0];

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <div>
          <span className="text-sm font-medium text-slate-200">{label}</span>
          <p className="text-xs text-slate-400">{description}</p>
        </div>
        <span className="text-sm text-slate-300 font-mono">
          {value >= 9999999 ? 'Never' : formatDuration(value)}
        </span>
      </div>

      <div className="flex flex-wrap gap-1">
        {Object.entries(THRESHOLD_PRESETS).map(([presetLabel, presetValue]) => (
          <button
            key={presetLabel}
            onClick={() => {
              onChange(presetValue);
              setIsCustom(false);
            }}
            disabled={disabled}
            className={`px-2 py-1 text-xs rounded transition-colors ${
              value === presetValue && !isCustom
                ? 'bg-indigo-500 text-white'
                : 'bg-slate-700 text-slate-300 hover:bg-slate-600'
            } ${disabled ? 'opacity-50 cursor-not-allowed' : ''}`}
          >
            {presetLabel}
          </button>
        ))}
        <button
          onClick={() => setIsCustom(!isCustom)}
          disabled={disabled}
          className={`px-2 py-1 text-xs rounded transition-colors ${
            isCustom || !matchingPreset
              ? 'bg-amber-500/20 text-amber-400'
              : 'bg-slate-700 text-slate-300 hover:bg-slate-600'
          } ${disabled ? 'opacity-50 cursor-not-allowed' : ''}`}
        >
          Custom
        </button>
      </div>

      {(isCustom || !matchingPreset) && (
        <div className="flex items-center gap-2 mt-2">
          <input
            type="number"
            min={0}
            max={999}
            value={customMinutes}
            onChange={(e) => setCustomMinutes(parseInt(e.target.value) || 0)}
            disabled={disabled}
            className="w-20 px-2 py-1 text-sm bg-slate-700 border border-slate-600 rounded text-slate-200 focus:outline-none focus:border-indigo-500"
          />
          <span className="text-sm text-slate-400">minutes</span>
          <button
            onClick={() => {
              onChange(customMinutes * 60);
              setIsCustom(false);
            }}
            disabled={disabled}
            className="px-2 py-1 text-xs bg-indigo-500 text-white rounded hover:bg-indigo-600 transition-colors"
          >
            Apply
          </button>
        </div>
      )}
    </div>
  );
}

interface ProfileEditorProps {
  profile?: { id: string } & PowerMode;
  isNew?: boolean;
  onSave: (profile: CreateProfileRequest) => Promise<void>;
  onCancel: () => void;
}

function ProfileEditor({ profile, isNew, onSave, onCancel }: ProfileEditorProps) {
  const [name, setName] = useState(profile?.name || '');
  const [id, setId] = useState(profile?.id || '');
  const [description, setDescription] = useState(profile?.description || '');
  const [enabled, setEnabled] = useState(profile?.enabled ?? true);
  const [thresholds, setThresholds] = useState({
    warm: profile?.thresholds?.warm ?? 30,
    cool: profile?.thresholds?.cool ?? 300,
    cold: profile?.thresholds?.cold ?? 1800,
    dormant: profile?.thresholds?.dormant ?? 7200,
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSave = async () => {
    if (!name.trim()) {
      setError('Name is required');
      return;
    }
    if (isNew && !id.trim()) {
      setError('ID is required');
      return;
    }

    // Validate threshold order
    if (thresholds.warm >= thresholds.cool) {
      setError('Warm threshold must be less than Cool');
      return;
    }
    if (thresholds.cool >= thresholds.cold) {
      setError('Cool threshold must be less than Cold');
      return;
    }
    if (thresholds.cold >= thresholds.dormant) {
      setError('Cold threshold must be less than Dormant');
      return;
    }

    setSaving(true);
    setError(null);

    try {
      await onSave({
        id: id.toLowerCase().replace(/\s+/g, '_'),
        name: name.trim(),
        description: description.trim(),
        thresholds,
        enabled,
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save profile');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-4 p-4 bg-slate-800/50 rounded-lg border border-slate-600">
      <div className="flex items-center justify-between">
        <h4 className="text-lg font-medium text-slate-100">
          {isNew ? 'Create New Profile' : 'Edit Profile'}
        </h4>
        <button
          onClick={onCancel}
          className="p-1 text-slate-400 hover:text-slate-200 transition-colors"
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      {error && (
        <div className="p-2 bg-red-500/20 border border-red-500/30 rounded text-red-400 text-sm flex items-center gap-2">
          <AlertTriangle className="w-4 h-4" />
          {error}
        </div>
      )}

      <div className="grid md:grid-cols-2 gap-4">
        <div>
          <label className="block text-sm text-slate-400 mb-1">Profile Name</label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="My Custom Profile"
            className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-slate-200 focus:outline-none focus:border-indigo-500"
          />
        </div>
        {isNew && (
          <div>
            <label className="block text-sm text-slate-400 mb-1">Profile ID</label>
            <input
              type="text"
              value={id}
              onChange={(e) => setId(e.target.value.toLowerCase().replace(/\s+/g, '_'))}
              placeholder="my_custom_profile"
              className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-slate-200 font-mono text-sm focus:outline-none focus:border-indigo-500"
            />
          </div>
        )}
      </div>

      <div>
        <label className="block text-sm text-slate-400 mb-1">Description</label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Describe when to use this profile..."
          rows={2}
          className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded text-slate-200 focus:outline-none focus:border-indigo-500 resize-none"
        />
      </div>

      <div className="flex items-center gap-2">
        <button
          onClick={() => setEnabled(!enabled)}
          className={`relative w-10 h-5 rounded-full transition-colors ${
            enabled ? 'bg-indigo-500' : 'bg-slate-600'
          }`}
        >
          <span
            className={`absolute top-0.5 w-4 h-4 bg-white rounded-full transition-transform ${
              enabled ? 'translate-x-5' : 'translate-x-0.5'
            }`}
          />
        </button>
        <span className="text-sm text-slate-300">
          Idle management {enabled ? 'enabled' : 'disabled'}
        </span>
      </div>

      <div className="border-t border-slate-700 pt-4 space-y-4">
        <h5 className="text-sm font-medium text-slate-300 flex items-center gap-2">
          <Clock className="w-4 h-4" />
          Idle Thresholds
        </h5>

        <ThresholdEditor
          label="→ Warm"
          description="Reduce polling frequency"
          value={thresholds.warm}
          onChange={(v) => setThresholds({ ...thresholds, warm: v })}
        />
        <ThresholdEditor
          label="→ Cool"
          description="Unload TTS model"
          value={thresholds.cool}
          onChange={(v) => setThresholds({ ...thresholds, cool: v })}
        />
        <ThresholdEditor
          label="→ Cold"
          description="Unload all models"
          value={thresholds.cold}
          onChange={(v) => setThresholds({ ...thresholds, cold: v })}
        />
        <ThresholdEditor
          label="→ Dormant"
          description="Minimal operation"
          value={thresholds.dormant}
          onChange={(v) => setThresholds({ ...thresholds, dormant: v })}
        />
      </div>

      <div className="flex justify-end gap-2 pt-2">
        <button
          onClick={onCancel}
          className="px-4 py-2 text-sm text-slate-400 hover:text-slate-200 transition-colors"
        >
          Cancel
        </button>
        <button
          onClick={handleSave}
          disabled={saving}
          className="px-4 py-2 text-sm bg-indigo-500 text-white rounded hover:bg-indigo-600 transition-colors flex items-center gap-2 disabled:opacity-50"
        >
          {saving ? (
            <RefreshCw className="w-4 h-4 animate-spin" />
          ) : (
            <Save className="w-4 h-4" />
          )}
          {isNew ? 'Create Profile' : 'Save Changes'}
        </button>
      </div>
    </div>
  );
}

export function PowerSettingsPanel() {
  const [powerModes, setPowerModes] = useState<PowerModesResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [expandedProfile, setExpandedProfile] = useState<string | null>(null);
  const [editingProfile, setEditingProfile] = useState<string | null>(null);
  const [creatingNew, setCreatingNew] = useState(false);
  const [duplicatingFrom, setDuplicatingFrom] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    try {
      const modesData = await getPowerModes();
      setPowerModes(modesData);
    } catch (error) {
      console.error('Error fetching power modes:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleSelectMode = async (modeId: string) => {
    setActionLoading(`select-${modeId}`);
    try {
      await setIdleConfig({ mode: modeId });
      await fetchData();
    } catch (error) {
      console.error('Error setting mode:', error);
    } finally {
      setActionLoading(null);
    }
  };

  const handleCreateProfile = async (profile: CreateProfileRequest) => {
    await createProfile(profile);
    setCreatingNew(false);
    await fetchData();
  };

  const handleUpdateProfile = async (profileId: string, profile: CreateProfileRequest) => {
    await updateProfile(profileId, {
      name: profile.name,
      description: profile.description,
      thresholds: profile.thresholds,
      enabled: profile.enabled,
    });
    setEditingProfile(null);
    await fetchData();
  };

  const handleDeleteProfile = async (profileId: string) => {
    if (!confirm(`Delete profile "${profileId}"? This cannot be undone.`)) return;

    setActionLoading(`delete-${profileId}`);
    try {
      await deleteProfile(profileId);
      await fetchData();
    } catch (error) {
      console.error('Error deleting profile:', error);
    } finally {
      setActionLoading(null);
    }
  };

  const handleDuplicateProfile = async (sourceId: string, newId: string, newName: string) => {
    await duplicateProfile(sourceId, newId, newName);
    setDuplicatingFrom(null);
    await fetchData();
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <RefreshCw className="w-8 h-8 animate-spin text-slate-400" />
      </div>
    );
  }

  const sortedModes = powerModes
    ? Object.entries(powerModes.modes).sort(([, a], [, b]) => {
        // Built-in first, then custom
        if (a.is_builtin && !b.is_builtin) return -1;
        if (!a.is_builtin && b.is_builtin) return 1;
        return a.name.localeCompare(b.name);
      })
    : [];

  return (
    <Card className="bg-slate-800/50 border-slate-700/50">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="text-lg flex items-center gap-2">
            <Sliders className="w-5 h-5 text-indigo-400" />
            Power Profiles
          </CardTitle>
          <button
            onClick={() => setCreatingNew(true)}
            disabled={creatingNew}
            className="px-3 py-1.5 text-sm bg-indigo-500 text-white rounded hover:bg-indigo-600 transition-colors flex items-center gap-2"
          >
            <Plus className="w-4 h-4" />
            New Profile
          </button>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Create New Profile Editor */}
        {creatingNew && (
          <ProfileEditor
            isNew
            onSave={handleCreateProfile}
            onCancel={() => setCreatingNew(false)}
          />
        )}

        {/* Profile List */}
        <div className="space-y-2">
          {sortedModes.map(([id, mode]) => {
            const isActive = powerModes?.current === id;
            const isExpanded = expandedProfile === id;
            const isEditing = editingProfile === id;
            const isDuplicating = duplicatingFrom === id;

            return (
              <div
                key={id}
                className={`rounded-lg border transition-all ${
                  isActive
                    ? 'border-indigo-500 bg-indigo-500/10'
                    : 'border-slate-700 bg-slate-800/30 hover:border-slate-600'
                }`}
              >
                {/* Profile Header */}
                <div
                  className="p-3 flex items-center justify-between cursor-pointer"
                  onClick={() => setExpandedProfile(isExpanded ? null : id)}
                >
                  <div className="flex items-center gap-3">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleSelectMode(id);
                      }}
                      disabled={actionLoading !== null || isActive}
                      className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors ${
                        isActive
                          ? 'border-indigo-500 bg-indigo-500'
                          : 'border-slate-500 hover:border-indigo-400'
                      }`}
                    >
                      {isActive && <Check className="w-3 h-3 text-white" />}
                      {actionLoading === `select-${id}` && (
                        <RefreshCw className="w-3 h-3 animate-spin text-slate-400" />
                      )}
                    </button>

                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-medium text-slate-100">{mode.name}</span>
                        {mode.is_builtin && (
                          <Badge variant="info" className="text-xs flex items-center">
                            <Lock className="w-3 h-3 mr-1" />
                            Built-in
                          </Badge>
                        )}
                        {mode.is_custom && (
                          <Badge variant="success" className="text-xs">
                            Custom
                          </Badge>
                        )}
                        {!mode.enabled && (
                          <Badge variant="warning" className="text-xs">
                            Idle Disabled
                          </Badge>
                        )}
                      </div>
                      <p className="text-xs text-slate-400">{mode.description}</p>
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    {isExpanded ? (
                      <ChevronUp className="w-4 h-4 text-slate-400" />
                    ) : (
                      <ChevronDown className="w-4 h-4 text-slate-400" />
                    )}
                  </div>
                </div>

                {/* Expanded Details */}
                {isExpanded && !isEditing && (
                  <div className="px-3 pb-3 border-t border-slate-700/50">
                    <div className="mt-3 grid grid-cols-4 gap-4 text-center">
                      <div className="p-2 bg-slate-700/30 rounded">
                        <p className="text-xs text-slate-400">Warm</p>
                        <p className="text-sm font-medium text-slate-200">
                          {mode.thresholds.warm >= 9999999 ? 'Never' : formatDuration(mode.thresholds.warm)}
                        </p>
                      </div>
                      <div className="p-2 bg-slate-700/30 rounded">
                        <p className="text-xs text-slate-400">Cool</p>
                        <p className="text-sm font-medium text-slate-200">
                          {mode.thresholds.cool >= 9999999 ? 'Never' : formatDuration(mode.thresholds.cool)}
                        </p>
                      </div>
                      <div className="p-2 bg-slate-700/30 rounded">
                        <p className="text-xs text-slate-400">Cold</p>
                        <p className="text-sm font-medium text-slate-200">
                          {mode.thresholds.cold >= 9999999 ? 'Never' : formatDuration(mode.thresholds.cold)}
                        </p>
                      </div>
                      <div className="p-2 bg-slate-700/30 rounded">
                        <p className="text-xs text-slate-400">Dormant</p>
                        <p className="text-sm font-medium text-slate-200">
                          {mode.thresholds.dormant >= 9999999 ? 'Never' : formatDuration(mode.thresholds.dormant)}
                        </p>
                      </div>
                    </div>

                    <div className="mt-3 flex justify-end gap-2">
                      <button
                        onClick={() => setDuplicatingFrom(id)}
                        className="px-2 py-1 text-xs bg-slate-700 text-slate-300 rounded hover:bg-slate-600 transition-colors flex items-center gap-1"
                      >
                        <Copy className="w-3 h-3" />
                        Duplicate
                      </button>
                      {mode.is_custom && (
                        <>
                          <button
                            onClick={() => setEditingProfile(id)}
                            className="px-2 py-1 text-xs bg-indigo-500/20 text-indigo-400 rounded hover:bg-indigo-500/30 transition-colors flex items-center gap-1"
                          >
                            <Settings className="w-3 h-3" />
                            Edit
                          </button>
                          <button
                            onClick={() => handleDeleteProfile(id)}
                            disabled={actionLoading === `delete-${id}`}
                            className="px-2 py-1 text-xs bg-red-500/20 text-red-400 rounded hover:bg-red-500/30 transition-colors flex items-center gap-1"
                          >
                            {actionLoading === `delete-${id}` ? (
                              <RefreshCw className="w-3 h-3 animate-spin" />
                            ) : (
                              <Trash2 className="w-3 h-3" />
                            )}
                            Delete
                          </button>
                        </>
                      )}
                    </div>

                    {/* Duplicate Form */}
                    {isDuplicating && (
                      <DuplicateForm
                        sourceName={mode.name}
                        onDuplicate={(newId, newName) => handleDuplicateProfile(id, newId, newName)}
                        onCancel={() => setDuplicatingFrom(null)}
                      />
                    )}
                  </div>
                )}

                {/* Editing Mode */}
                {isEditing && (
                  <div className="px-3 pb-3 border-t border-slate-700/50 mt-2">
                    <ProfileEditor
                      profile={{ id, ...mode }}
                      onSave={(profile) => handleUpdateProfile(id, profile)}
                      onCancel={() => setEditingProfile(null)}
                    />
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Help Text */}
        <div className="mt-4 p-3 bg-slate-900/50 rounded-lg border border-slate-700/50">
          <div className="flex items-start gap-2">
            <Zap className="w-4 h-4 text-amber-400 mt-0.5 shrink-0" />
            <div className="text-xs text-slate-400">
              <p className="font-medium text-slate-300 mb-1">Power Profile Tips</p>
              <ul className="space-y-1 list-disc list-inside">
                <li>Create custom profiles for different work scenarios (coding, demos, background)</li>
                <li>Shorter thresholds save more power but increase wake-up latency</li>
                <li>Use &quot;Keep Awake&quot; in the Health panel for temporary override</li>
                <li>Duplicate a built-in profile to customize it</li>
              </ul>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

// Simple duplicate form component
function DuplicateForm({
  sourceName,
  onDuplicate,
  onCancel,
}: {
  sourceName: string;
  onDuplicate: (newId: string, newName: string) => void;
  onCancel: () => void;
}) {
  const [newName, setNewName] = useState(`${sourceName} (Copy)`);
  // Derive newId from newName directly instead of using useEffect + setState
  const newId = newName.toLowerCase().replace(/[^a-z0-9]+/g, '_');

  return (
    <div className="mt-3 p-3 bg-slate-700/30 rounded-lg">
      <p className="text-sm text-slate-300 mb-2">Duplicate as new profile:</p>
      <div className="flex gap-2">
        <input
          type="text"
          value={newName}
          onChange={(e) => setNewName(e.target.value)}
          placeholder="New profile name"
          className="flex-1 px-2 py-1 text-sm bg-slate-700 border border-slate-600 rounded text-slate-200 focus:outline-none focus:border-indigo-500"
        />
        <button
          onClick={() => onDuplicate(newId, newName)}
          disabled={!newName.trim()}
          className="px-3 py-1 text-sm bg-indigo-500 text-white rounded hover:bg-indigo-600 transition-colors disabled:opacity-50"
        >
          Create
        </button>
        <button
          onClick={onCancel}
          className="px-3 py-1 text-sm text-slate-400 hover:text-slate-200 transition-colors"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}
