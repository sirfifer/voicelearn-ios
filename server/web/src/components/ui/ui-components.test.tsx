import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Badge, BadgeVariant } from './badge';
import { Input } from './input';
import { Label } from './label';

describe('Badge', () => {
  it('renders children', () => {
    render(<Badge>Test Badge</Badge>);
    expect(screen.getByText('Test Badge')).toBeInTheDocument();
  });

  it('applies default variant styles', () => {
    render(<Badge>Default</Badge>);
    const badge = screen.getByText('Default');
    expect(badge).toHaveClass('bg-slate-600/50');
  });

  it('applies custom variant styles', () => {
    const variants: BadgeVariant[] = ['success', 'warning', 'error', 'info'];
    const expectedClasses = [
      'bg-emerald-500/20',
      'bg-amber-500/20',
      'bg-red-500/20',
      'bg-blue-500/20',
    ];

    variants.forEach((variant, index) => {
      const { unmount } = render(<Badge variant={variant}>Test</Badge>);
      const badge = screen.getByText('Test');
      expect(badge).toHaveClass(expectedClasses[index]);
      unmount();
    });
  });

  it('applies custom className', () => {
    render(<Badge className="custom-class">Test</Badge>);
    expect(screen.getByText('Test')).toHaveClass('custom-class');
  });
});

describe('Input', () => {
  it('renders input element', () => {
    render(<Input placeholder="Enter text" />);
    expect(screen.getByPlaceholderText('Enter text')).toBeInTheDocument();
  });

  it('applies default type of text', () => {
    render(<Input data-testid="input" />);
    expect(screen.getByTestId('input')).toHaveAttribute('type', 'text');
  });

  it('accepts custom type', () => {
    render(<Input type="email" data-testid="input" />);
    expect(screen.getByTestId('input')).toHaveAttribute('type', 'email');
  });

  it('applies custom className', () => {
    render(<Input className="custom-input" data-testid="input" />);
    expect(screen.getByTestId('input')).toHaveClass('custom-input');
  });
});

describe('Label', () => {
  it('renders children', () => {
    render(<Label>Test Label</Label>);
    expect(screen.getByText('Test Label')).toBeInTheDocument();
  });

  it('applies custom className', () => {
    render(<Label className="custom-label">Test</Label>);
    expect(screen.getByText('Test')).toHaveClass('custom-label');
  });
});
