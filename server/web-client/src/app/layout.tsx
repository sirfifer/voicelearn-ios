'use client';

/**
 * Root Layout
 *
 * Wraps the entire application with providers and sets up responsive layout.
 * Includes the TooltipProvider for contextual help throughout the app.
 */

import * as React from 'react';
import { Inter } from 'next/font/google';
import { AuthProvider } from '@/components/auth/AuthProvider';
import { TooltipProvider } from '@/components/help';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <title>UnaMentis - Voice AI Tutoring</title>
        <meta name="description" content="Voice AI tutoring platform for personalized learning" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </head>
      <body className={`${inter.className} antialiased bg-background text-foreground`}>
        <TooltipProvider delayDuration={400}>
          <AuthProvider>{children}</AuthProvider>
        </TooltipProvider>
      </body>
    </html>
  );
}
