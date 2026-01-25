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
        <title>UnaMentis - Voice AI Learning</title>
        <meta name="description" content="Voice AI learning platform for personalized learning. Real-time bidirectional voice conversations for extended learning sessions." />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="theme-color" content="#1e3a5f" />
        <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png" />
        <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png" />
        <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />
        <meta property="og:title" content="UnaMentis - Voice AI Learning" />
        <meta property="og:description" content="Real-time bidirectional voice learning" />
        <meta property="og:image" content="/images/logo-expanded.png" />
        <meta property="og:type" content="website" />
      </head>
      <body className={`${inter.className} antialiased bg-background text-foreground`}>
        <TooltipProvider delayDuration={400}>
          <AuthProvider>{children}</AuthProvider>
        </TooltipProvider>
      </body>
    </html>
  );
}
