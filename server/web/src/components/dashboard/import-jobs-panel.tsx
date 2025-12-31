'use client';

import { useState, useEffect } from 'react';
import { Download, RefreshCw, XCircle, CheckCircle, Clock, Loader2, Play } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import type { ImportProgress, ImportStatus } from '@/types';

interface ImportJobsResponse {
  success: boolean;
  jobs: ImportProgress[];
  error?: string;
}

// API functions for import jobs
async function getImportJobs(status?: string): Promise<ImportJobsResponse> {
  const url = status ? `/api/import/jobs?status=${status}` : '/api/import/jobs';
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error('Failed to fetch import jobs');
  }
  return response.json();
}

async function cancelImportJob(jobId: string): Promise<void> {
  const response = await fetch(`/api/import/jobs/${jobId}`, { method: 'DELETE' });
  if (!response.ok) {
    throw new Error('Failed to cancel import job');
  }
}

const statusConfig: Record<ImportStatus, { icon: typeof Clock; color: string; label: string }> = {
  queued: { icon: Clock, color: 'bg-slate-500/20 text-slate-400 border-slate-500/30', label: 'Queued' },
  downloading: { icon: Download, color: 'bg-blue-500/20 text-blue-400 border-blue-500/30', label: 'Downloading' },
  validating: { icon: Loader2, color: 'bg-violet-500/20 text-violet-400 border-violet-500/30', label: 'Validating' },
  extracting: { icon: Loader2, color: 'bg-indigo-500/20 text-indigo-400 border-indigo-500/30', label: 'Extracting' },
  enriching: { icon: Loader2, color: 'bg-cyan-500/20 text-cyan-400 border-cyan-500/30', label: 'Enriching' },
  generating: { icon: Loader2, color: 'bg-teal-500/20 text-teal-400 border-teal-500/30', label: 'Generating' },
  storing: { icon: Loader2, color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30', label: 'Storing' },
  completed: { icon: CheckCircle, color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30', label: 'Completed' },
  failed: { icon: XCircle, color: 'bg-red-500/20 text-red-400 border-red-500/30', label: 'Failed' },
  cancelled: { icon: XCircle, color: 'bg-amber-500/20 text-amber-400 border-amber-500/30', label: 'Cancelled' },
};

function formatDuration(startedAt: string, endedAt?: string): string {
  const start = new Date(startedAt).getTime();
  const end = endedAt ? new Date(endedAt).getTime() : Date.now();
  const durationMs = end - start;

  const seconds = Math.floor(durationMs / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);

  if (hours > 0) {
    return `${hours}h ${minutes % 60}m`;
  } else if (minutes > 0) {
    return `${minutes}m ${seconds % 60}s`;
  } else {
    return `${seconds}s`;
  }
}

export function ImportJobsPanel() {
  const [jobs, setJobs] = useState<ImportProgress[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<string>('all');

  const fetchJobs = async () => {
    setLoading(true);
    setError(null);
    try {
      const status = filter === 'all' ? undefined : filter;
      const data = await getImportJobs(status);
      setJobs(data.jobs);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load import jobs');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchJobs();

    // Poll for updates every 5 seconds when there are active jobs
    const interval = setInterval(() => {
      const hasActiveJobs = jobs.some(
        (job) => !['completed', 'failed', 'cancelled'].includes(job.status)
      );
      if (hasActiveJobs) {
        fetchJobs();
      }
    }, 5000);

    return () => clearInterval(interval);
  }, [filter]);

  const handleCancel = async (jobId: string) => {
    if (!confirm('Are you sure you want to cancel this import job?')) {
      return;
    }
    try {
      await cancelImportJob(jobId);
      await fetchJobs();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to cancel job');
    }
  };

  const activeJobs = jobs.filter((j) => !['completed', 'failed', 'cancelled'].includes(j.status));
  const completedJobs = jobs.filter((j) => ['completed', 'failed', 'cancelled'].includes(j.status));

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-white flex items-center gap-2">
            <Download className="w-6 h-6 text-orange-400" />
            Import Jobs
          </h2>
          <p className="text-slate-400 mt-1">
            Monitor and manage curriculum import jobs
          </p>
        </div>

        <div className="flex items-center gap-2">
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="px-3 py-2 text-sm bg-slate-800 border border-slate-700 rounded-md text-slate-300 focus:outline-none focus:ring-2 focus:ring-orange-500/50"
          >
            <option value="all">All Jobs</option>
            <option value="queued">Queued</option>
            <option value="downloading">In Progress</option>
            <option value="completed">Completed</option>
            <option value="failed">Failed</option>
          </select>

          <button
            onClick={fetchJobs}
            className="flex items-center gap-2 px-3 py-2 text-sm font-medium text-slate-300 bg-slate-800 hover:bg-slate-700 rounded-md transition-colors"
          >
            <RefreshCw className="w-4 h-4" />
            Refresh
          </button>
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <div className="p-4 bg-red-500/10 border border-red-500/30 rounded-md text-red-400">
          {error}
        </div>
      )}

      {/* Loading */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin w-8 h-8 border-2 border-orange-500 border-t-transparent rounded-full" />
        </div>
      ) : jobs.length === 0 ? (
        <Card className="bg-slate-900/50 border-slate-800">
          <CardContent className="flex flex-col items-center justify-center py-12 text-center">
            <Download className="w-12 h-12 text-slate-600 mb-4" />
            <h3 className="text-lg font-medium text-slate-300 mb-2">No import jobs</h3>
            <p className="text-slate-500 max-w-md">
              Start an import from the Sources tab to see jobs here
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-6">
          {/* Active Jobs */}
          {activeJobs.length > 0 && (
            <div className="space-y-4">
              <h3 className="text-lg font-medium text-slate-200 flex items-center gap-2">
                <Play className="w-5 h-5 text-blue-400" />
                Active Jobs ({activeJobs.length})
              </h3>

              <div className="space-y-3">
                {activeJobs.map((job) => {
                  const config = statusConfig[job.status] || statusConfig.queued;
                  const StatusIcon = config.icon;

                  return (
                    <Card key={job.jobId} className="bg-slate-900/50 border-slate-800">
                      <CardContent className="p-4">
                        <div className="flex items-start justify-between gap-4">
                          <div className="flex-1">
                            <div className="flex items-center gap-2 mb-2">
                              <h4 className="font-medium text-slate-100">
                                {job.courseName}
                              </h4>
                              <Badge className={config.color}>
                                <StatusIcon className="w-3 h-3 mr-1 animate-spin" />
                                {config.label}
                              </Badge>
                            </div>

                            <p className="text-sm text-slate-400 mb-3">
                              {job.currentStage}
                            </p>

                            {/* Progress Bar */}
                            <div className="space-y-2">
                              <div className="flex justify-between text-xs text-slate-500">
                                <span>Stage: {Math.round(job.stageProgress)}%</span>
                                <span>Overall: {Math.round(job.overallProgress)}%</span>
                              </div>
                              <div className="h-2 bg-slate-800 rounded-full overflow-hidden">
                                <div
                                  className="h-full bg-gradient-to-r from-blue-500 to-cyan-500 transition-all duration-300"
                                  style={{ width: `${job.overallProgress}%` }}
                                />
                              </div>
                            </div>

                            {/* Stats */}
                            <div className="flex items-center gap-4 mt-3 text-xs text-slate-500">
                              <span>Files: {job.stats.filesProcessed}/{job.stats.filesDownloaded}</span>
                              <span>Topics: {job.stats.topicsCreated}</span>
                              <span>Duration: {formatDuration(job.startedAt)}</span>
                            </div>
                          </div>

                          <button
                            onClick={() => handleCancel(job.jobId)}
                            className="p-2 text-slate-400 hover:text-red-400 transition-colors"
                            title="Cancel"
                          >
                            <XCircle className="w-5 h-5" />
                          </button>
                        </div>
                      </CardContent>
                    </Card>
                  );
                })}
              </div>
            </div>
          )}

          {/* Completed Jobs */}
          {completedJobs.length > 0 && (
            <div className="space-y-4">
              <h3 className="text-lg font-medium text-slate-200 flex items-center gap-2">
                <CheckCircle className="w-5 h-5 text-slate-400" />
                Completed Jobs ({completedJobs.length})
              </h3>

              <div className="space-y-2">
                {completedJobs.map((job) => {
                  const config = statusConfig[job.status] || statusConfig.queued;
                  const StatusIcon = config.icon;

                  return (
                    <Card key={job.jobId} className="bg-slate-900/50 border-slate-800">
                      <CardContent className="p-4">
                        <div className="flex items-center justify-between gap-4">
                          <div className="flex-1">
                            <div className="flex items-center gap-2">
                              <h4 className="font-medium text-slate-100">
                                {job.courseName}
                              </h4>
                              <Badge className={config.color}>
                                <StatusIcon className="w-3 h-3 mr-1" />
                                {config.label}
                              </Badge>
                            </div>

                            {job.error && (
                              <p className="text-sm text-red-400 mt-1">
                                {job.error}
                              </p>
                            )}

                            <div className="flex items-center gap-4 mt-2 text-xs text-slate-500">
                              <span>Topics: {job.stats.topicsCreated}</span>
                              <span>
                                Duration: {formatDuration(job.startedAt, job.completedAt)}
                              </span>
                              {job.completedAt && (
                                <span>
                                  Finished: {new Date(job.completedAt).toLocaleString()}
                                </span>
                              )}
                            </div>
                          </div>
                        </div>
                      </CardContent>
                    </Card>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
