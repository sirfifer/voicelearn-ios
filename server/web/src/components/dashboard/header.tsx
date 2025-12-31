'use client';

import { useState, useEffect } from 'react';
import { Activity, FileText, Users } from 'lucide-react';
import { cn } from '@/lib/utils';
import { isUsingMockData } from '@/lib/api-client';

interface HeaderProps {
  stats?: {
    logsCount: number;
    clientsCount: number;
  };
  connected?: boolean;
}

export function Header({ stats, connected = false }: HeaderProps) {
  const [currentTime, setCurrentTime] = useState('--:--:--');
  const isMock = isUsingMockData();

  useEffect(() => {
    const updateTime = () => {
      setCurrentTime(new Date().toLocaleTimeString('en-US', { hour12: false }));
    };
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  return (
    <header className="border-b border-slate-700/50 bg-slate-900/95 backdrop-blur-xl safe-area-top">
      <div className="max-w-[1920px] mx-auto px-3 sm:px-6 py-2 sm:py-3">
        <div className="flex items-center justify-between gap-2">
          {/* Logo and Title */}
          <div className="flex items-center gap-2 sm:gap-3 min-w-0">
            <div className="w-8 h-8 sm:w-9 sm:h-9 rounded-lg bg-gradient-to-br from-orange-500 to-amber-600 flex items-center justify-center shadow-lg shadow-orange-500/20 flex-shrink-0">
              <Activity className="w-4 h-4 sm:w-5 sm:h-5 text-white" />
            </div>
            <div className="min-w-0">
              <h1 className="text-sm sm:text-lg font-bold text-slate-100 truncate">
                UnaMentis Server
              </h1>
              <p className="text-[9px] sm:text-[10px] text-slate-500 uppercase tracking-wider hidden sm:block">
                System Management Console
              </p>
            </div>
          </div>

          {/* Right side controls */}
          <div className="flex items-center gap-2 sm:gap-4 flex-shrink-0">
            {/* Connection Status - compact on mobile */}
            <div className={cn(
              'flex items-center gap-1.5 sm:gap-2 px-2 sm:px-3 py-1 sm:py-1.5 rounded-full border text-xs sm:text-sm',
              isMock
                ? 'bg-amber-500/10 border-amber-500/30'
                : connected
                  ? 'bg-emerald-500/10 border-emerald-500/30'
                  : 'bg-slate-800/50 border-slate-700/50'
            )}>
              <div className={cn(
                'w-1.5 h-1.5 sm:w-2 sm:h-2 rounded-full',
                isMock
                  ? 'bg-amber-400 animate-pulse'
                  : connected
                    ? 'bg-emerald-400 animate-pulse'
                    : 'bg-slate-500'
              )} />
              <span className={cn(
                isMock
                  ? 'text-amber-400'
                  : connected
                    ? 'text-emerald-400'
                    : 'text-slate-400'
              )}>
                {/* Short text on mobile */}
                <span className="sm:hidden">
                  {isMock ? 'Demo' : connected ? 'Live' : '...'}
                </span>
                <span className="hidden sm:inline">
                  {isMock ? 'Demo Mode' : connected ? 'Connected' : 'Connecting...'}
                </span>
              </span>
            </div>

            {/* Quick Stats - hidden on small screens */}
            <div className="hidden md:flex items-center gap-3 text-sm">
              <div className="flex items-center gap-1.5">
                <FileText className="w-3.5 h-3.5 text-emerald-400" />
                <span className="text-slate-300">
                  <span className="font-semibold text-slate-100">{stats?.logsCount ?? 0}</span>
                </span>
              </div>
              <div className="flex items-center gap-1.5">
                <Users className="w-3.5 h-3.5 text-blue-400" />
                <span className="text-slate-300">
                  <span className="font-semibold text-slate-100">{stats?.clientsCount ?? 0}</span>
                </span>
              </div>
            </div>

            {/* Time - always visible but smaller on mobile */}
            <div className="text-xs sm:text-sm text-slate-400 font-mono tabular-nums">
              {currentTime}
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
