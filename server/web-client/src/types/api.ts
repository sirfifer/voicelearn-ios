/**
 * API Request/Response Types
 * Based on Management API Reference
 */

// ===== Common Response Types =====

export interface ApiSuccessResponse<T = unknown> {
  success: true;
  data?: T;
}

export interface ApiErrorResponse {
  error: string;
  message: string;
  code: string;
  details?: Record<string, unknown>;
}

export type ApiResponse<T = unknown> = ApiSuccessResponse<T> | ApiErrorResponse;

// ===== Pagination =====

export interface PaginationParams {
  page?: number;
  pageSize?: number;
}

export interface PaginationInfo {
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

export interface PaginatedResponse<T> {
  items: T[];
  pagination: PaginationInfo;
}

// ===== Health & System =====

export interface HealthResponse {
  status: 'healthy' | 'degraded' | 'unhealthy';
  server_time: string;
  uptime_seconds: number;
  version: string;
}

export interface SystemMetrics {
  cpu_percent: number;
  memory_percent: number;
  disk_percent: number;
  gpu_percent: number;
  temperature: number;
  timestamp: string;
}

export interface SystemSnapshot {
  timestamp: string;
  metrics: SystemMetrics;
  processes: Array<{
    pid: number;
    name: string;
    cpu_percent: number;
    memory_mb: number;
  }>;
}

export interface ServerStats {
  total_logs_received: number;
  total_metrics_received: number;
  online_clients: number;
  registered_servers: number;
  uptime_seconds: number;
}

// ===== Logs & Metrics =====

export interface LogEntry {
  id: string;
  timestamp: string;
  level: 'DEBUG' | 'INFO' | 'WARNING' | 'ERROR';
  label: string;
  message: string;
  file?: string;
  function?: string;
  line?: number;
  metadata?: Record<string, unknown>;
  client_id?: string;
  client_name?: string;
}

export interface MetricEntry {
  id: string;
  client_id: string;
  client_name: string;
  timestamp: string;
  memory_mb: number;
  cpu_percent: number;
  network_latency_ms?: number;
  custom_metrics?: Record<string, number>;
}

// ===== Client Management =====

export interface ConnectedClient {
  client_id: string;
  client_name: string;
  status: 'online' | 'offline';
  last_heartbeat: string;
  created_at: string;
  logs_sent: number;
  metrics_sent: number;
}

export interface HeartbeatRequest {
  client_id: string;
  client_name: string;
  status: 'online' | 'offline';
  memory_mb?: number;
  cpu_percent?: number;
}

// ===== Media Generation =====

export interface MediaCapabilities {
  diagrams: {
    formats: string[];
    renderers: Record<string, boolean>;
  };
  formulas: {
    renderers: Record<string, boolean>;
    clientSideSupported: boolean;
  };
  maps: {
    styles: string[];
    renderers: Record<string, boolean>;
    features: string[];
  };
}

export interface DiagramRenderRequest {
  format: 'mermaid' | 'graphviz' | 'plantuml' | 'd2';
  code: string;
  outputFormat?: 'svg' | 'png';
  theme?: string;
  width?: number;
  height?: number;
}

export interface FormulaRenderRequest {
  latex: string;
  outputFormat?: 'svg' | 'png';
  displayMode?: boolean;
  fontSize?: number;
  color?: string;
}

export interface MapRenderRequest {
  title?: string;
  center: {
    latitude: number;
    longitude: number;
  };
  zoom: number;
  style?: string;
  width?: number;
  height?: number;
  outputFormat?: 'png' | 'svg';
  markers?: Array<{
    latitude: number;
    longitude: number;
    label: string;
    color?: string;
  }>;
  routes?: Array<{
    points: Array<[number, number]>;
    label?: string;
    color?: string;
    width?: number;
  }>;
  regions?: Array<{
    points: Array<[number, number]>;
    label?: string;
    fillColor?: string;
    fillOpacity?: number;
  }>;
}

export interface MediaRenderResponse {
  success: true;
  data: string; // base64 encoded
  mimeType: string;
  width: number;
  height: number;
  renderMethod: string;
}

// ===== Import =====

export interface ImportSource {
  id: string;
  name: string;
  description: string;
  url: string;
  icon_url?: string;
  license_type: string;
  supported_features: string[];
}

export interface ImportCourse {
  id: string;
  title: string;
  description: string;
  instructor?: string;
  subject: string;
  level: string;
  language: string;
  duration?: number;
  featured?: boolean;
  available_features: string[];
}

export interface ImportJobRequest {
  sourceId: string;
  courseId: string;
  outputName?: string;
  selectedLectures?: string[];
  includeTranscripts?: boolean;
  includeLectureNotes?: boolean;
  includeAssignments?: boolean;
  generateObjectives?: boolean;
  createCheckpoints?: boolean;
  generateSpokenText?: boolean;
}

export interface ImportProgress {
  id: string;
  source_id: string;
  course_id: string;
  status: 'queued' | 'in_progress' | 'complete' | 'failed' | 'cancelled';
  percent_complete: number;
  current_step: string;
  items_processed: number;
  items_total: number;
  errors: string[];
  warnings: string[];
  started_at: string;
  estimated_completion_at?: string;
}

// ===== Plugins =====

export interface Plugin {
  plugin_id: string;
  name: string;
  version: string;
  description: string;
  author: string;
  enabled: boolean;
  priority: number;
  settings: Record<string, unknown>;
  has_config: boolean;
}

// ===== WebSocket =====

export interface WebSocketMessage {
  type: string;
  data?: unknown;
  timestamp?: number;
}

export interface WebSocketConnectedMessage extends WebSocketMessage {
  type: 'connected';
  data: {
    server_time: string;
    stats: ServerStats;
  };
}

// ===== Rate Limiting =====

export interface RateLimitInfo {
  limit: number;
  remaining: number;
  reset: number;
  window: number;
}
