'use client';

import { useState } from 'react';
import { X, Plus, Loader2 } from 'lucide-react';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import type {
  TTSProfile,
  TTSProvider,
  CreateProfileData,
  UpdateProfileData,
  TTSProfileSettings,
} from '@/types';

interface ProfileEditorProps {
  profile?: TTSProfile | null;
  onSave: (data: CreateProfileData | UpdateProfileData) => Promise<void>;
  onCancel: () => void;
  isLoading?: boolean;
}

const TTS_PROVIDERS = [
  { value: 'chatterbox', label: 'Chatterbox' },
  { value: 'vibevoice', label: 'VibeVoice' },
  { value: 'piper', label: 'Piper' },
];

const USE_CASES = [
  { value: 'tutoring', label: 'Tutoring' },
  { value: 'questions', label: 'Questions' },
  { value: 'explanations', label: 'Explanations' },
  { value: 'hints', label: 'Hints' },
  { value: 'narration', label: 'Narration' },
];

const DEFAULT_SETTINGS: TTSProfileSettings = {
  speed: 1.0,
  exaggeration: 0.5,
  cfg_weight: 0.5,
};

export function ProfileEditor({ profile, onSave, onCancel, isLoading }: ProfileEditorProps) {
  const isEditing = Boolean(profile);

  const [name, setName] = useState(profile?.name || '');
  const [description, setDescription] = useState(profile?.description || '');
  const [provider, setProvider] = useState<TTSProvider>(profile?.provider || 'chatterbox');
  const [voiceId, setVoiceId] = useState(profile?.voice_id || 'default');
  const [useCase, setUseCase] = useState(profile?.use_case || '');
  const [settings, setSettings] = useState<TTSProfileSettings>(
    profile?.settings || { ...DEFAULT_SETTINGS }
  );
  const [tags, setTags] = useState<string[]>(profile?.tags || []);
  const [tagInput, setTagInput] = useState('');

  // Track previous profile to reset form when a different profile is selected
  const [prevProfileId, setPrevProfileId] = useState(profile?.id);
  if (profile?.id !== prevProfileId) {
    setPrevProfileId(profile?.id);
    if (profile) {
      setName(profile.name);
      setDescription(profile.description || '');
      setProvider(profile.provider);
      setVoiceId(profile.voice_id);
      setUseCase(profile.use_case || '');
      setSettings(profile.settings || { ...DEFAULT_SETTINGS });
      setTags(profile.tags || []);
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const data: CreateProfileData | UpdateProfileData = {
      name,
      description: description || undefined,
      provider,
      voice_id: voiceId,
      use_case: useCase || undefined,
      settings,
      tags,
    };

    await onSave(data);
  };

  const updateSetting = (key: keyof TTSProfileSettings, value: number) => {
    setSettings((prev) => ({ ...prev, [key]: value }));
  };

  const addTag = () => {
    const tag = tagInput.trim().toLowerCase();
    if (tag && !tags.includes(tag)) {
      setTags([...tags, tag]);
      setTagInput('');
    }
  };

  const removeTag = (tagToRemove: string) => {
    setTags(tags.filter((t) => t !== tagToRemove));
  };

  const handleTagKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addTag();
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <Card className="bg-slate-900 border-slate-700 w-full max-w-2xl max-h-[90vh] overflow-hidden flex flex-col">
        <CardHeader className="flex flex-row items-center justify-between p-4 border-b border-slate-700">
          <h2 className="text-lg font-semibold text-white">
            {isEditing ? 'Edit TTS Profile' : 'Create TTS Profile'}
          </h2>
          <Button
            variant="ghost"
            size="icon"
            onClick={onCancel}
            className="text-slate-400 hover:text-white"
          >
            <X className="h-5 w-5" />
          </Button>
        </CardHeader>

        <CardContent className="p-4 overflow-y-auto flex-1">
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Basic Info */}
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-1.5">Name *</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) => setName(e.target.value)}
                  placeholder="e.g., Knowledge Bowl Tutor"
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-md text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-orange-500/50 focus:border-orange-500"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-slate-300 mb-1.5">
                  Description
                </label>
                <textarea
                  value={description}
                  onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) =>
                    setDescription(e.target.value)
                  }
                  placeholder="Describe the voice characteristics and intended use..."
                  rows={3}
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-md text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-orange-500/50 focus:border-orange-500 resize-none"
                />
              </div>
            </div>

            {/* Provider & Voice */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-1.5">
                  Provider *
                </label>
                <select
                  value={provider}
                  onChange={(e: React.ChangeEvent<HTMLSelectElement>) =>
                    setProvider(e.target.value as TTSProvider)
                  }
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-md text-white focus:outline-none focus:ring-2 focus:ring-orange-500/50 focus:border-orange-500"
                >
                  {TTS_PROVIDERS.map((p) => (
                    <option key={p.value} value={p.value}>
                      {p.label}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-slate-300 mb-1.5">
                  Voice ID *
                </label>
                <input
                  type="text"
                  value={voiceId}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) => setVoiceId(e.target.value)}
                  placeholder="e.g., default, nova"
                  className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-md text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-orange-500/50 focus:border-orange-500"
                  required
                />
              </div>
            </div>

            {/* Use Case */}
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">Use Case</label>
              <select
                value={useCase}
                onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setUseCase(e.target.value)}
                className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-md text-white focus:outline-none focus:ring-2 focus:ring-orange-500/50 focus:border-orange-500"
              >
                <option value="">Select a use case...</option>
                {USE_CASES.map((uc) => (
                  <option key={uc.value} value={uc.value}>
                    {uc.label}
                  </option>
                ))}
              </select>
            </div>

            {/* Voice Settings */}
            <div className="space-y-4">
              <h3 className="text-sm font-medium text-slate-300">Voice Settings</h3>

              {/* Speed */}
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label className="text-sm text-slate-400">Speed</label>
                  <span className="text-sm text-slate-300">
                    {settings.speed?.toFixed(2) ?? '1.00'}x
                  </span>
                </div>
                <input
                  type="range"
                  min="0.5"
                  max="2.0"
                  step="0.05"
                  value={settings.speed ?? 1.0}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                    updateSetting('speed', parseFloat(e.target.value))
                  }
                  className="w-full h-2 bg-slate-700 rounded-lg appearance-none cursor-pointer accent-orange-500"
                />
              </div>

              {/* Exaggeration (Chatterbox) */}
              {provider === 'chatterbox' && (
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-sm text-slate-400">Exaggeration</label>
                    <span className="text-sm text-slate-300">
                      {settings.exaggeration?.toFixed(2) ?? '0.50'}
                    </span>
                  </div>
                  <input
                    type="range"
                    min="0"
                    max="1"
                    step="0.05"
                    value={settings.exaggeration ?? 0.5}
                    onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                      updateSetting('exaggeration', parseFloat(e.target.value))
                    }
                    className="w-full h-2 bg-slate-700 rounded-lg appearance-none cursor-pointer accent-orange-500"
                  />
                </div>
              )}

              {/* CFG Weight (Chatterbox) */}
              {provider === 'chatterbox' && (
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-sm text-slate-400">CFG Weight</label>
                    <span className="text-sm text-slate-300">
                      {settings.cfg_weight?.toFixed(2) ?? '0.50'}
                    </span>
                  </div>
                  <input
                    type="range"
                    min="0"
                    max="1"
                    step="0.05"
                    value={settings.cfg_weight ?? 0.5}
                    onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                      updateSetting('cfg_weight', parseFloat(e.target.value))
                    }
                    className="w-full h-2 bg-slate-700 rounded-lg appearance-none cursor-pointer accent-orange-500"
                  />
                </div>
              )}
            </div>

            {/* Tags */}
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1.5">Tags</label>
              <div className="flex gap-2 mb-2">
                <input
                  type="text"
                  value={tagInput}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) => setTagInput(e.target.value)}
                  onKeyDown={handleTagKeyDown}
                  placeholder="Add a tag..."
                  className="flex-1 px-3 py-2 bg-slate-800 border border-slate-700 rounded-md text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-orange-500/50 focus:border-orange-500"
                />
                <Button
                  type="button"
                  variant="outline"
                  size="icon"
                  onClick={addTag}
                  className="border-slate-700 text-slate-300"
                >
                  <Plus className="h-4 w-4" />
                </Button>
              </div>
              {tags.length > 0 && (
                <div className="flex flex-wrap gap-1">
                  {tags.map((tag) => (
                    <Badge
                      key={tag}
                      variant="outline"
                      className="bg-slate-700/50 border-slate-600 text-slate-300 flex items-center gap-1"
                    >
                      {tag}
                      <button
                        type="button"
                        onClick={() => removeTag(tag)}
                        className="ml-1 hover:text-white"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </Badge>
                  ))}
                </div>
              )}
            </div>

            {/* Actions */}
            <div className="flex justify-end gap-3 pt-4 border-t border-slate-700">
              <Button
                type="button"
                variant="outline"
                onClick={onCancel}
                className="border-slate-700 text-slate-300"
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={isLoading || !name || !voiceId}
                className="bg-orange-500 hover:bg-orange-600 text-white"
              >
                {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                {isEditing ? 'Update Profile' : 'Create Profile'}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
