'use client';

/**
 * Home Page / Dashboard
 *
 * Landing page for authenticated users, showing quick actions and recent sessions.
 */

import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { Mic, BookOpen, Settings, LogOut, Play } from 'lucide-react';
import { useAuth } from '@/components/auth/AuthProvider';
import { Button, Card } from '@/components/ui';
import { HelpButton } from '@/components/help';

export default function HomePage() {
  const router = useRouter();
  const { isAuthenticated, isLoading, user, logout } = useAuth();

  // Show loading state
  if (isLoading) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <div className="text-center">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent mx-auto" />
          <p className="mt-4 text-muted-foreground">Loading...</p>
        </div>
      </main>
    );
  }

  // Redirect to login if not authenticated
  if (!isAuthenticated) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center p-8">
        <div className="text-center max-w-md">
          <h1 className="text-4xl font-bold mb-4">UnaMentis</h1>
          <p className="text-lg text-muted-foreground mb-8">
            Voice AI learning platform for personalized learning
          </p>
          <div className="flex gap-4 justify-center">
            <Link href="/login">
              <Button size="lg">Sign In</Button>
            </Link>
            <Link href="/register">
              <Button variant="outline" size="lg">
                Sign Up
              </Button>
            </Link>
          </div>
        </div>
      </main>
    );
  }

  // Authenticated user dashboard
  return (
    <main className="min-h-screen">
      {/* Header */}
      <header className="border-b">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <h1 className="text-xl font-bold">UnaMentis</h1>
          <div className="flex items-center gap-4">
            <span className="text-sm text-muted-foreground">
              Welcome, {user?.display_name || user?.email}
            </span>
            <HelpButton />
            <Button variant="ghost" size="icon" onClick={() => router.push('/settings')}>
              <Settings className="h-5 w-5" />
            </Button>
            <Button variant="ghost" size="icon" onClick={logout}>
              <LogOut className="h-5 w-5" />
            </Button>
          </div>
        </div>
      </header>

      {/* Main content */}
      <div className="container mx-auto px-4 py-8">
        <h2 className="text-2xl font-semibold mb-6">Get Started</h2>

        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {/* Start Session Card */}
          <Card
            className="p-6 cursor-pointer hover:shadow-lg transition-shadow"
            onClick={() => router.push('/session')}
          >
            <div className="flex items-center gap-4 mb-4">
              <div className="p-3 rounded-full bg-primary/10">
                <Mic className="h-6 w-6 text-primary" />
              </div>
              <h3 className="text-lg font-semibold">Start Session</h3>
            </div>
            <p className="text-muted-foreground mb-4">
              Begin a voice learning session.
            </p>
            <Button className="w-full">
              <Play className="h-4 w-4 mr-2" />
              Start Learning
            </Button>
          </Card>

          {/* Browse Curricula Card */}
          <Card
            className="p-6 cursor-pointer hover:shadow-lg transition-shadow"
            onClick={() => router.push('/curriculum')}
          >
            <div className="flex items-center gap-4 mb-4">
              <div className="p-3 rounded-full bg-blue-500/10">
                <BookOpen className="h-6 w-6 text-blue-500" />
              </div>
              <h3 className="text-lg font-semibold">Curricula</h3>
            </div>
            <p className="text-muted-foreground mb-4">
              Browse available curricula and choose what to study.
            </p>
            <Button variant="outline" className="w-full">
              Browse Curricula
            </Button>
          </Card>

          {/* Settings Card */}
          <Card
            className="p-6 cursor-pointer hover:shadow-lg transition-shadow"
            onClick={() => router.push('/settings')}
          >
            <div className="flex items-center gap-4 mb-4">
              <div className="p-3 rounded-full bg-gray-500/10">
                <Settings className="h-6 w-6 text-gray-500" />
              </div>
              <h3 className="text-lg font-semibold">Settings</h3>
            </div>
            <p className="text-muted-foreground mb-4">
              Configure your learning preferences and account settings.
            </p>
            <Button variant="outline" className="w-full">
              Open Settings
            </Button>
          </Card>
        </div>
      </div>
    </main>
  );
}
