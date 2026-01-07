'use client';

/**
 * Settings Page
 *
 * User settings and preferences configuration.
 */

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft, User, Volume2, Mic, Bell, Shield, LogOut } from 'lucide-react';
import { useAuth } from '@/components/auth/AuthProvider';
import { Button, Card, Input, Label } from '@/components/ui';

export default function SettingsPage() {
  const router = useRouter();
  const { isAuthenticated, isLoading, user, logout } = useAuth();

  // Redirect if not authenticated
  React.useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      router.push('/login');
    }
  }, [isAuthenticated, isLoading, router]);

  const handleLogout = React.useCallback(async () => {
    await logout();
    router.push('/');
  }, [logout, router]);

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

  if (!isAuthenticated) {
    return null;
  }

  return (
    <main className="min-h-screen">
      {/* Header */}
      <div className="flex items-center gap-2 px-4 py-3 border-b">
        <Button variant="ghost" size="icon" onClick={() => router.push('/')}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <h1 className="text-lg font-semibold">Settings</h1>
      </div>

      {/* Settings Content */}
      <div className="container mx-auto px-4 py-6 max-w-2xl space-y-6">
        {/* Profile Section */}
        <Card className="p-6">
          <div className="flex items-center gap-4 mb-6">
            <div className="p-3 rounded-full bg-primary/10">
              <User className="h-6 w-6 text-primary" />
            </div>
            <div>
              <h2 className="text-lg font-semibold">Profile</h2>
              <p className="text-sm text-muted-foreground">Manage your account information</p>
            </div>
          </div>

          <div className="space-y-4">
            <div>
              <Label htmlFor="displayName">Display Name</Label>
              <Input
                id="displayName"
                defaultValue={user?.display_name || ''}
                placeholder="Your name"
                className="mt-1"
              />
            </div>
            <div>
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                defaultValue={user?.email || ''}
                disabled
                className="mt-1 bg-muted"
              />
              <p className="text-xs text-muted-foreground mt-1">Email cannot be changed</p>
            </div>
          </div>
        </Card>

        {/* Voice Settings */}
        <Card className="p-6">
          <div className="flex items-center gap-4 mb-6">
            <div className="p-3 rounded-full bg-blue-500/10">
              <Volume2 className="h-6 w-6 text-blue-500" />
            </div>
            <div>
              <h2 className="text-lg font-semibold">Voice Settings</h2>
              <p className="text-sm text-muted-foreground">Configure voice interaction preferences</p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium">Voice Speed</p>
                <p className="text-sm text-muted-foreground">Adjust AI speaking speed</p>
              </div>
              <select className="border rounded-md px-3 py-2">
                <option value="slow">Slow</option>
                <option value="normal" selected>
                  Normal
                </option>
                <option value="fast">Fast</option>
              </select>
            </div>
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium">Auto-detect speech</p>
                <p className="text-sm text-muted-foreground">Start recording when you speak</p>
              </div>
              <input type="checkbox" defaultChecked className="h-5 w-5" />
            </div>
          </div>
        </Card>

        {/* Microphone Settings */}
        <Card className="p-6">
          <div className="flex items-center gap-4 mb-6">
            <div className="p-3 rounded-full bg-green-500/10">
              <Mic className="h-6 w-6 text-green-500" />
            </div>
            <div>
              <h2 className="text-lg font-semibold">Microphone</h2>
              <p className="text-sm text-muted-foreground">Select and test your microphone</p>
            </div>
          </div>

          <div className="space-y-4">
            <div>
              <Label htmlFor="microphone">Input Device</Label>
              <select id="microphone" className="w-full border rounded-md px-3 py-2 mt-1">
                <option>Default Microphone</option>
              </select>
            </div>
            <Button variant="outline" className="w-full">
              Test Microphone
            </Button>
          </div>
        </Card>

        {/* Notifications */}
        <Card className="p-6">
          <div className="flex items-center gap-4 mb-6">
            <div className="p-3 rounded-full bg-amber-500/10">
              <Bell className="h-6 w-6 text-amber-500" />
            </div>
            <div>
              <h2 className="text-lg font-semibold">Notifications</h2>
              <p className="text-sm text-muted-foreground">Manage notification preferences</p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium">Session reminders</p>
                <p className="text-sm text-muted-foreground">Get reminded to practice</p>
              </div>
              <input type="checkbox" defaultChecked className="h-5 w-5" />
            </div>
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium">Progress updates</p>
                <p className="text-sm text-muted-foreground">Weekly learning progress</p>
              </div>
              <input type="checkbox" defaultChecked className="h-5 w-5" />
            </div>
          </div>
        </Card>

        {/* Security */}
        <Card className="p-6">
          <div className="flex items-center gap-4 mb-6">
            <div className="p-3 rounded-full bg-red-500/10">
              <Shield className="h-6 w-6 text-red-500" />
            </div>
            <div>
              <h2 className="text-lg font-semibold">Security</h2>
              <p className="text-sm text-muted-foreground">Account security settings</p>
            </div>
          </div>

          <div className="space-y-4">
            <Button variant="outline" className="w-full">
              Change Password
            </Button>
            <Button variant="outline" className="w-full">
              Manage Devices
            </Button>
          </div>
        </Card>

        {/* Logout */}
        <Card className="p-6 border-destructive/50">
          <div className="flex items-center gap-4 mb-4">
            <div className="p-3 rounded-full bg-destructive/10">
              <LogOut className="h-6 w-6 text-destructive" />
            </div>
            <div>
              <h2 className="text-lg font-semibold">Sign Out</h2>
              <p className="text-sm text-muted-foreground">Sign out of your account</p>
            </div>
          </div>

          <Button variant="destructive" className="w-full" onClick={handleLogout}>
            Sign Out
          </Button>
        </Card>
      </div>
    </main>
  );
}
