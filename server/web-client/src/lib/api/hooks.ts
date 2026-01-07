/**
 * SWR Data Fetching Hooks
 *
 * React hooks for fetching and caching API data using SWR.
 */

import useSWR, { type SWRConfiguration, type SWRResponse } from 'swr';
import useSWRMutation, { type SWRMutationConfiguration } from 'swr/mutation';
import { get, post, ApiError } from './client';
import { tokenManager } from './token-manager';
import type {
  Curriculum,
  CurriculumSummary,
  User,
  HealthResponse,
  ServerStats,
  MediaCapabilities,
  ImportSource,
  ImportCourse,
  ImportProgress,
  Plugin,
  SessionHistoryEntry,
} from '@/types';

// Default SWR config
const defaultConfig: SWRConfiguration = {
  revalidateOnFocus: false,
  revalidateOnReconnect: true,
  shouldRetryOnError: (error: Error) => {
    // Don't retry on auth errors
    if (error instanceof ApiError && error.isAuthError()) {
      return false;
    }
    return true;
  },
};

/**
 * Generic fetcher for SWR using our API client.
 */
async function fetcher<T>(endpoint: string): Promise<T> {
  return get<T>(endpoint);
}

// ===== Auth Hooks =====

/**
 * Hook to get and cache the current user.
 */
export function useUser(
  config?: SWRConfiguration<{ user: User }>
): SWRResponse<{ user: User }, ApiError> & { user: User | undefined } {
  const shouldFetch = tokenManager.hasTokens();

  const result = useSWR<{ user: User }, ApiError>(
    shouldFetch ? '/auth/me' : null,
    fetcher,
    { ...defaultConfig, ...config }
  );

  return {
    ...result,
    user: result.data?.user,
  };
}

// ===== Curriculum Hooks =====

/**
 * Hook to list all curricula.
 */
export function useCurricula(
  config?: SWRConfiguration<{ curricula: CurriculumSummary[] }>
): SWRResponse<{ curricula: CurriculumSummary[] }, ApiError> & {
  curricula: CurriculumSummary[];
} {
  const result = useSWR<{ curricula: CurriculumSummary[] }, ApiError>(
    '/curricula',
    fetcher,
    { ...defaultConfig, ...config }
  );

  return {
    ...result,
    curricula: result.data?.curricula || [],
  };
}

/**
 * Hook to get a single curriculum with topics.
 */
export function useCurriculum(
  curriculumId: string | null | undefined,
  config?: SWRConfiguration<{ curriculum: Curriculum }>
): SWRResponse<{ curriculum: Curriculum }, ApiError> & {
  curriculum: Curriculum | undefined;
} {
  const result = useSWR<{ curriculum: Curriculum }, ApiError>(
    curriculumId ? `/curricula/${curriculumId}` : null,
    fetcher,
    { ...defaultConfig, ...config }
  );

  return {
    ...result,
    curriculum: result.data?.curriculum,
  };
}

/**
 * Hook to get topic transcript.
 */
export function useTopicTranscript(
  curriculumId: string | null | undefined,
  topicId: string | null | undefined,
  config?: SWRConfiguration<{ transcript: { segments: unknown[] } }>
): SWRResponse<{ transcript: { segments: unknown[] } }, ApiError> {
  return useSWR<{ transcript: { segments: unknown[] } }, ApiError>(
    curriculumId && topicId
      ? `/curricula/${curriculumId}/topics/${topicId}/transcript`
      : null,
    fetcher,
    { ...defaultConfig, ...config }
  );
}

// ===== Session History Hooks =====

/**
 * Hook to get session history.
 */
export function useSessionHistory(
  config?: SWRConfiguration<{ sessions: SessionHistoryEntry[] }>
): SWRResponse<{ sessions: SessionHistoryEntry[] }, ApiError> & {
  sessions: SessionHistoryEntry[];
} {
  const result = useSWR<{ sessions: SessionHistoryEntry[] }, ApiError>(
    '/sessions/history',
    fetcher,
    { ...defaultConfig, ...config }
  );

  return {
    ...result,
    sessions: result.data?.sessions || [],
  };
}

// ===== System Hooks =====

/**
 * Hook to get server health.
 */
export function useHealth(
  config?: SWRConfiguration<HealthResponse>
): SWRResponse<HealthResponse, ApiError> {
  return useSWR<HealthResponse, ApiError>('/health', fetcher, {
    ...defaultConfig,
    refreshInterval: 30000, // Refresh every 30 seconds
    ...config,
  });
}

/**
 * Hook to get server stats.
 */
export function useServerStats(
  config?: SWRConfiguration<ServerStats>
): SWRResponse<ServerStats, ApiError> {
  return useSWR<ServerStats, ApiError>('/stats', fetcher, {
    ...defaultConfig,
    refreshInterval: 10000, // Refresh every 10 seconds
    ...config,
  });
}

// ===== Media Hooks =====

/**
 * Hook to get media rendering capabilities.
 */
export function useMediaCapabilities(
  config?: SWRConfiguration<{ success: true; capabilities: MediaCapabilities }>
): SWRResponse<{ success: true; capabilities: MediaCapabilities }, ApiError> & {
  capabilities: MediaCapabilities | undefined;
} {
  const result = useSWR<
    { success: true; capabilities: MediaCapabilities },
    ApiError
  >('/media/capabilities', fetcher, { ...defaultConfig, ...config });

  return {
    ...result,
    capabilities: result.data?.capabilities,
  };
}

// ===== Import Hooks =====

/**
 * Hook to list import sources.
 */
export function useImportSources(
  config?: SWRConfiguration<{ success: true; sources: ImportSource[] }>
): SWRResponse<{ success: true; sources: ImportSource[] }, ApiError> & {
  sources: ImportSource[];
} {
  const result = useSWR<{ success: true; sources: ImportSource[] }, ApiError>(
    '/import/sources',
    fetcher,
    { ...defaultConfig, ...config }
  );

  return {
    ...result,
    sources: result.data?.sources || [],
  };
}

/**
 * Hook to list courses from an import source.
 */
export function useImportCourses(
  sourceId: string | null | undefined,
  params?: { page?: number; pageSize?: number; search?: string },
  config?: SWRConfiguration
): SWRResponse<
  { success: true; courses: ImportCourse[]; pagination: unknown },
  ApiError
> & {
  courses: ImportCourse[];
} {
  const queryParams = new URLSearchParams();
  if (params?.page) queryParams.set('page', params.page.toString());
  if (params?.pageSize) queryParams.set('pageSize', params.pageSize.toString());
  if (params?.search) queryParams.set('search', params.search);

  const queryString = queryParams.toString();
  const endpoint = sourceId
    ? `/import/sources/${sourceId}/courses${queryString ? `?${queryString}` : ''}`
    : null;

  const result = useSWR<
    { success: true; courses: ImportCourse[]; pagination: unknown },
    ApiError
  >(endpoint, fetcher, { ...defaultConfig, ...config });

  return {
    ...result,
    courses: result.data?.courses || [],
  };
}

/**
 * Hook to get import job progress.
 */
export function useImportProgress(
  jobId: string | null | undefined,
  config?: SWRConfiguration<{ success: true; progress: ImportProgress }>
): SWRResponse<{ success: true; progress: ImportProgress }, ApiError> & {
  progress: ImportProgress | undefined;
} {
  const result = useSWR<{ success: true; progress: ImportProgress }, ApiError>(
    jobId ? `/import/jobs/${jobId}` : null,
    fetcher,
    {
      ...defaultConfig,
      refreshInterval: 2000, // Poll every 2 seconds while active
      ...config,
    }
  );

  return {
    ...result,
    progress: result.data?.progress,
  };
}

// ===== Plugin Hooks =====

/**
 * Hook to list plugins.
 */
export function usePlugins(
  config?: SWRConfiguration<{
    success: true;
    plugins: Plugin[];
    first_run: boolean;
  }>
): SWRResponse<
  { success: true; plugins: Plugin[]; first_run: boolean },
  ApiError
> & {
  plugins: Plugin[];
  firstRun: boolean;
} {
  const result = useSWR<
    { success: true; plugins: Plugin[]; first_run: boolean },
    ApiError
  >('/plugins', fetcher, { ...defaultConfig, ...config });

  return {
    ...result,
    plugins: result.data?.plugins || [],
    firstRun: result.data?.first_run ?? false,
  };
}

// ===== Mutation Hooks =====

interface MutationFetcherArg<T> {
  arg: T;
}

/**
 * Hook for starting an import job.
 */
export function useStartImportJob(
  config?: SWRMutationConfiguration<
    { success: true; jobId: string; status: string },
    ApiError,
    string,
    {
      sourceId: string;
      courseId: string;
      outputName?: string;
      selectedLectures?: string[];
    }
  >
) {
  return useSWRMutation<
    { success: true; jobId: string; status: string },
    ApiError,
    string,
    {
      sourceId: string;
      courseId: string;
      outputName?: string;
      selectedLectures?: string[];
    }
  >(
    '/import/jobs',
    async (
      _key: string,
      {
        arg,
      }: MutationFetcherArg<{
        sourceId: string;
        courseId: string;
        outputName?: string;
        selectedLectures?: string[];
      }>
    ) => {
      return post('/import/jobs', arg);
    },
    config
  );
}

/**
 * Hook for reloading curricula.
 */
export function useReloadCurricula(
  config?: SWRMutationConfiguration<
    { message: string; curricula_count: number },
    ApiError,
    string,
    void
  >
) {
  return useSWRMutation<
    { message: string; curricula_count: number },
    ApiError,
    string,
    void
  >(
    '/curricula/reload',
    async () => {
      return post('/curricula/reload', {});
    },
    config
  );
}
