'use client';

import * as React from 'react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  RadialLinearScale,
  Title,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';
import { Bar, Line, Pie, Scatter, Radar } from 'react-chartjs-2';
import { cn } from '@/lib/utils';
import type { ChartData } from '@/types';

// Register Chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  RadialLinearScale,
  Title,
  Tooltip,
  Legend,
  Filler
);

// ===== Types =====

export type ChartType = 'bar' | 'line' | 'pie' | 'scatter' | 'radar';

export interface ChartRendererProps {
  data: ChartData;
  type: ChartType;
  title?: string;
  className?: string;
  height?: number;
}


// ===== Transform Data for Chart.js =====

function transformData(data: ChartData, type: ChartType) {
  const defaultColors = [
    'rgba(59, 130, 246, 0.8)',   // blue
    'rgba(16, 185, 129, 0.8)',   // green
    'rgba(245, 158, 11, 0.8)',   // amber
    'rgba(239, 68, 68, 0.8)',    // red
    'rgba(139, 92, 246, 0.8)',   // purple
    'rgba(236, 72, 153, 0.8)',   // pink
    'rgba(6, 182, 212, 0.8)',    // cyan
  ];

  const borderColors = defaultColors.map((c) => c.replace('0.8', '1'));

  return {
    labels: data.labels,
    datasets: data.datasets.map((dataset, index) => ({
      ...dataset,
      backgroundColor:
        dataset.backgroundColor ||
        (type === 'pie' ? defaultColors : defaultColors[index % defaultColors.length]),
      borderColor:
        dataset.borderColor ||
        (type === 'pie' ? borderColors : borderColors[index % borderColors.length]),
      borderWidth: type === 'pie' ? 2 : 2,
      tension: type === 'line' ? 0.3 : undefined,
      fill: type === 'radar' ? true : undefined,
    })),
  };
}

// ===== Chart Renderer Component =====

function ChartRenderer({ data, type, title, className, height = 300 }: ChartRendererProps) {
  const chartData = React.useMemo(() => transformData(data, type), [data, type]);

  const renderChart = () => {
    const baseOptions = {
      responsive: true,
      maintainAspectRatio: true,
      plugins: {
        legend: {
          position: 'top' as const,
          labels: {
            usePointStyle: true,
            padding: 16,
          },
        },
        title: {
          display: !!title,
          text: title || '',
          padding: { bottom: 16 },
          font: {
            size: 14,
            weight: 'bold' as const,
          },
        },
        tooltip: {
          backgroundColor: 'rgba(0, 0, 0, 0.8)',
          padding: 12,
          cornerRadius: 8,
        },
      },
    };

    switch (type) {
      case 'bar':
        return (
          <Bar
            data={chartData}
            options={{
              ...baseOptions,
              scales: { y: { beginAtZero: true } },
            }}
          />
        );
      case 'line':
        return (
          <Line
            data={chartData}
            options={{
              ...baseOptions,
              scales: { y: { beginAtZero: true } },
            }}
          />
        );
      case 'pie':
        return (
          <Pie
            data={chartData}
            options={{
              ...baseOptions,
              cutout: '0%',
            }}
          />
        );
      case 'scatter':
        return (
          <Scatter
            data={chartData}
            options={{
              ...baseOptions,
              scales: {
                x: { type: 'linear' as const, position: 'bottom' as const },
                y: { beginAtZero: true },
              },
            }}
          />
        );
      case 'radar':
        return (
          <Radar
            data={chartData}
            options={{
              ...baseOptions,
              scales: { r: { beginAtZero: true } },
            }}
          />
        );
      default:
        return <Bar data={chartData} options={baseOptions} />;
    }
  };

  return (
    <div
      className={cn('chart-container p-4 bg-background rounded-lg', className)}
      style={{ height }}
      role="img"
      aria-label={title || `${type} chart`}
    >
      {renderChart()}
    </div>
  );
}

export { ChartRenderer };
