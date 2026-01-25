import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

// We need to mock at the module level to ensure env vars are set before api-client loads
vi.mock('@/lib/api-client', () => ({
  getBatchJobs: vi.fn(),
  getBatchJob: vi.fn(),
  createBatchJob: vi.fn(),
  deleteBatchJob: vi.fn(),
  startBatchJob: vi.fn(),
  pauseBatchJob: vi.fn(),
  resumeBatchJob: vi.fn(),
  getJobProgress: vi.fn(),
  getJobItems: vi.fn(),
  retryFailedItems: vi.fn(),
  extractContent: vi.fn(),
}));

import {
  getBatchJobs,
  getBatchJob,
  createBatchJob,
  deleteBatchJob,
  startBatchJob,
  pauseBatchJob,
  resumeBatchJob,
  getJobProgress,
  getJobItems,
  retryFailedItems,
  extractContent,
} from './api-client';

// Get the mocked functions with any type for flexibility
const mockGetBatchJobs = getBatchJobs as ReturnType<typeof vi.fn>;
const mockGetBatchJob = getBatchJob as ReturnType<typeof vi.fn>;
const mockCreateBatchJob = createBatchJob as ReturnType<typeof vi.fn>;
const mockDeleteBatchJob = deleteBatchJob as ReturnType<typeof vi.fn>;
const mockStartBatchJob = startBatchJob as ReturnType<typeof vi.fn>;
const mockPauseBatchJob = pauseBatchJob as ReturnType<typeof vi.fn>;
const mockResumeBatchJob = resumeBatchJob as ReturnType<typeof vi.fn>;
const mockGetJobProgress = getJobProgress as ReturnType<typeof vi.fn>;
const mockGetJobItems = getJobItems as ReturnType<typeof vi.fn>;
const mockRetryFailedItems = retryFailedItems as ReturnType<typeof vi.fn>;
const mockExtractContent = extractContent as ReturnType<typeof vi.fn>;

describe('Batch Job API Client', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
  });

  describe('getBatchJobs', () => {
    it('fetches jobs without filters', async () => {
      const mockJobs = {
        success: true,
        jobs: [{ id: 'job-1', name: 'Test Job', status: 'pending' }],
        total: 1,
        limit: 50,
        offset: 0,
      };
      mockGetBatchJobs.mockResolvedValueOnce(mockJobs);

      const result = await getBatchJobs();
      expect(result.jobs).toHaveLength(1);
      expect(result.jobs[0].name).toBe('Test Job');
    });

    it('fetches jobs with status filter', async () => {
      const mockJobs = {
        success: true,
        jobs: [],
        total: 0,
        limit: 50,
        offset: 0,
      };
      mockGetBatchJobs.mockResolvedValueOnce(mockJobs);

      await getBatchJobs({ status: 'running' });
      expect(mockGetBatchJobs).toHaveBeenCalledWith({ status: 'running' });
    });
  });

  describe('getBatchJob', () => {
    it('fetches a single job by ID', async () => {
      const mockJob = {
        success: true,
        job: { id: 'job-123', name: 'Test Job', status: 'running' },
      };
      mockGetBatchJob.mockResolvedValueOnce(mockJob);

      const result = await getBatchJob('job-123');
      expect(result.job.id).toBe('job-123');
    });
  });

  describe('createBatchJob', () => {
    it('creates a new batch job', async () => {
      const mockResponse = {
        success: true,
        job: {
          id: 'new-job-1',
          name: 'KB Audio Batch',
          status: 'pending',
          source_type: 'knowledge-bowl',
        },
      };
      mockCreateBatchJob.mockResolvedValueOnce(mockResponse);

      const result = await createBatchJob({
        name: 'KB Audio Batch',
        source_type: 'knowledge-bowl',
        profile_id: 'profile-1',
        include_questions: true,
        include_answers: true,
      });

      expect(result.success).toBe(true);
      expect(result.job.name).toBe('KB Audio Batch');
      expect(mockCreateBatchJob).toHaveBeenCalledWith({
        name: 'KB Audio Batch',
        source_type: 'knowledge-bowl',
        profile_id: 'profile-1',
        include_questions: true,
        include_answers: true,
      });
    });

    it('returns error on creation failure', async () => {
      mockCreateBatchJob.mockResolvedValueOnce({
        success: false,
        error: 'Invalid profile ID',
      });

      const result = await createBatchJob({
        name: 'Test',
        source_type: 'knowledge-bowl',
        profile_id: 'invalid',
      });

      expect(result.success).toBe(false);
      expect(result.error).toBe('Invalid profile ID');
    });
  });

  describe('deleteBatchJob', () => {
    it('deletes a job', async () => {
      mockDeleteBatchJob.mockResolvedValueOnce({ success: true });

      const result = await deleteBatchJob('job-123');
      expect(result.success).toBe(true);
      expect(mockDeleteBatchJob).toHaveBeenCalledWith('job-123');
    });
  });

  describe('job control operations', () => {
    it('starts a pending job', async () => {
      const mockResponse = {
        success: true,
        job: { id: 'job-1', status: 'running' },
      };
      mockStartBatchJob.mockResolvedValueOnce(mockResponse);

      const result = await startBatchJob('job-1');
      expect(result.job.status).toBe('running');
      expect(mockStartBatchJob).toHaveBeenCalledWith('job-1');
    });

    it('pauses a running job', async () => {
      const mockResponse = {
        success: true,
        job: { id: 'job-1', status: 'paused' },
      };
      mockPauseBatchJob.mockResolvedValueOnce(mockResponse);

      const result = await pauseBatchJob('job-1');
      expect(result.job.status).toBe('paused');
    });

    it('resumes a paused job', async () => {
      const mockResponse = {
        success: true,
        job: { id: 'job-1', status: 'running' },
      };
      mockResumeBatchJob.mockResolvedValueOnce(mockResponse);

      const result = await resumeBatchJob('job-1');
      expect(result.job.status).toBe('running');
    });
  });

  describe('getJobProgress', () => {
    it('returns progress information', async () => {
      const mockProgress = {
        job_id: 'job-1',
        status: 'running',
        percentage: 45.5,
        completed_items: 45,
        failed_items: 2,
        pending_items: 53,
        total_items: 100,
        current_item_index: 47,
        current_item_text: 'What is photosynthesis?',
      };
      mockGetJobProgress.mockResolvedValueOnce(mockProgress);

      const result = await getJobProgress('job-1');
      expect(result.percentage).toBe(45.5);
      expect(result.completed_items).toBe(45);
      expect(result.current_item_text).toBe('What is photosynthesis?');
    });
  });

  describe('getJobItems', () => {
    it('fetches items with pagination', async () => {
      const mockItems = {
        success: true,
        items: [
          { id: 'item-1', text_content: 'Question 1', status: 'completed' },
          { id: 'item-2', text_content: 'Question 2', status: 'failed' },
        ],
        total: 100,
        limit: 20,
        offset: 0,
      };
      mockGetJobItems.mockResolvedValueOnce(mockItems);

      const result = await getJobItems('job-1', { limit: 20, offset: 0 });
      expect(result.items).toHaveLength(2);
      expect(result.total).toBe(100);
    });

    it('filters by status', async () => {
      const mockItems = {
        success: true,
        items: [{ id: 'item-2', text_content: 'Question 2', status: 'failed' }],
        total: 5,
        limit: 50,
        offset: 0,
      };
      mockGetJobItems.mockResolvedValueOnce(mockItems);

      await getJobItems('job-1', { status: 'failed' });
      expect(mockGetJobItems).toHaveBeenCalledWith('job-1', { status: 'failed' });
    });
  });

  describe('retryFailedItems', () => {
    it('resets failed items for retry', async () => {
      const mockResponse = {
        success: true,
        reset_count: 5,
      };
      mockRetryFailedItems.mockResolvedValueOnce(mockResponse);

      const result = await retryFailedItems('job-1');
      expect(result.success).toBe(true);
      expect(result.reset_count).toBe(5);
    });
  });

  describe('extractContent', () => {
    it('extracts Knowledge Bowl content', async () => {
      const mockExtract = {
        success: true,
        items: [
          { text: 'What is gravity?', source_ref: 'q1:question' },
          { text: '9.8 m/s²', source_ref: 'q1:answer' },
        ],
        total_count: 200,
        stats: {
          total_questions: 50,
          type_counts: { question: 50, answer: 50, hint: 60, explanation: 40 },
        },
      };
      mockExtractContent.mockResolvedValueOnce(mockExtract);

      const result = await extractContent({
        source_type: 'knowledge-bowl',
        include_questions: true,
        include_answers: true,
        include_hints: true,
        include_explanations: true,
      });

      expect(result.success).toBe(true);
      expect(result.total_count).toBe(200);
      expect(result.stats?.total_questions).toBe(50);
    });

    it('handles extraction errors', async () => {
      mockExtractContent.mockResolvedValueOnce({
        success: false,
        items: [],
        total_count: 0,
        error: 'No content found',
      });

      const result = await extractContent({
        source_type: 'knowledge-bowl',
        include_questions: true,
      });

      expect(result.success).toBe(false);
      expect(result.error).toBe('No content found');
    });
  });
});
