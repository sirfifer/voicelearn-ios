// TTS Pre-Generation Types
// Types for TTS profiles, batch jobs, and comparison sessions

// ============================================================================
// Enums
// ============================================================================

export type TTSProvider = 'chatterbox' | 'vibevoice' | 'piper';

export type JobStatus = 'pending' | 'running' | 'paused' | 'completed' | 'failed' | 'cancelled';

export type ItemStatus = 'pending' | 'processing' | 'completed' | 'failed' | 'skipped';

export type SessionStatus = 'draft' | 'generating' | 'ready' | 'archived';

export type VariantStatus = 'pending' | 'generating' | 'ready' | 'failed';

// ============================================================================
// TTS Profiles
// ============================================================================

export interface TTSProfileSettings {
  speed: number;
  exaggeration?: number;
  cfg_weight?: number;
  language?: string;
  extra?: Record<string, unknown>;
}

export interface TTSProfile {
  id: string;
  name: string;
  description?: string;
  provider: TTSProvider;
  voice_id: string;
  settings: TTSProfileSettings;
  tags: string[];
  use_case?: string;
  is_active: boolean;
  is_default: boolean;
  created_at: string;
  updated_at: string;
  created_from_session_id?: string;
  sample_audio_path?: string;
  sample_text?: string;
}

export interface TTSModuleProfile {
  id: string;
  module_id: string;
  profile_id: string;
  context?: string;
  priority: number;
  created_at: string;
}

export interface ModuleProfileAssignment {
  association: {
    id: string;
    context?: string;
    priority: number;
    created_at: string;
  };
  profile: TTSProfile;
}

// ============================================================================
// Batch Jobs
// ============================================================================

export interface TTSPregenJob {
  id: string;
  name: string;
  job_type: 'batch' | 'comparison';
  status: JobStatus;
  source_type: string;
  source_id?: string;
  profile_id?: string;
  tts_config?: Record<string, unknown>;
  output_format: string;
  normalize_volume: boolean;
  output_dir: string;
  total_items: number;
  completed_items: number;
  failed_items: number;
  current_item_index: number;
  current_item_text?: string;
  created_at: string;
  started_at?: string;
  paused_at?: string;
  completed_at?: string;
  updated_at: string;
  last_error?: string;
  consecutive_failures: number;
}

export interface TTSJobItem {
  id: string;
  job_id: string;
  item_index: number;
  text_content: string;
  text_hash: string;
  source_ref?: string;
  status: ItemStatus;
  attempt_count: number;
  output_file?: string;
  duration_seconds?: number;
  file_size_bytes?: number;
  sample_rate?: number;
  last_error?: string;
  processing_started_at?: string;
  processing_completed_at?: string;
}

// ============================================================================
// Comparison Sessions
// ============================================================================

export interface TTSComparisonConfig {
  samples: Array<{
    text: string;
    source_ref?: string;
  }>;
  configurations: Array<{
    name: string;
    provider: TTSProvider;
    voice_id: string;
    settings: TTSProfileSettings;
  }>;
}

export interface TTSComparisonSession {
  id: string;
  name: string;
  description?: string;
  status: SessionStatus;
  config: TTSComparisonConfig;
  created_at: string;
  updated_at: string;
}

export interface TTSComparisonVariant {
  id: string;
  session_id: string;
  sample_index: number;
  config_index: number;
  text_content: string;
  tts_config: Record<string, unknown>;
  status: VariantStatus;
  output_file?: string;
  duration_seconds?: number;
  last_error?: string;
}

export interface TTSComparisonRating {
  id: string;
  variant_id: string;
  rating?: number;
  notes?: string;
  rated_at: string;
}

// ============================================================================
// API Response Types
// ============================================================================

export interface ProfilesResponse {
  success: boolean;
  profiles: TTSProfile[];
  total: number;
  limit: number;
  offset: number;
  error?: string;
}

export interface ProfileResponse {
  success: boolean;
  profile: TTSProfile;
  error?: string;
}

export interface ModuleProfilesResponse {
  success: boolean;
  module_id: string;
  profiles: ModuleProfileAssignment[];
  error?: string;
}

export interface JobsResponse {
  success: boolean;
  jobs: TTSPregenJob[];
  total: number;
  limit: number;
  offset: number;
  error?: string;
}

export interface JobResponse {
  success: boolean;
  job: TTSPregenJob;
  error?: string;
}

export interface SessionsResponse {
  success: boolean;
  sessions: TTSComparisonSession[];
  total: number;
  limit: number;
  offset: number;
  error?: string;
}

export interface SessionResponse {
  success: boolean;
  session: TTSComparisonSession;
  variants?: TTSComparisonVariant[];
  ratings?: Record<string, TTSComparisonRating>;
  error?: string;
}

// ============================================================================
// Form/Create Types
// ============================================================================

export interface CreateProfileData {
  name: string;
  provider: TTSProvider;
  voice_id: string;
  settings?: Partial<TTSProfileSettings>;
  description?: string;
  tags?: string[];
  use_case?: string;
  is_default?: boolean;
  generate_sample?: boolean;
  sample_text?: string;
}

export interface UpdateProfileData {
  name?: string;
  description?: string;
  provider?: TTSProvider;
  voice_id?: string;
  settings?: Partial<TTSProfileSettings>;
  tags?: string[];
  use_case?: string;
  regenerate_sample?: boolean;
  sample_text?: string;
}

export interface CreateJobData {
  name: string;
  source_type: string;
  source_id?: string;
  profile_id?: string;
  tts_config?: Record<string, unknown>;
  output_format?: string;
  normalize_volume?: boolean;
}

export interface CreateSessionData {
  name: string;
  description?: string;
  samples: Array<{ text: string; source_ref?: string }>;
  configurations: Array<{
    name: string;
    provider: TTSProvider;
    voice_id: string;
    settings: Partial<TTSProfileSettings>;
  }>;
}
