'use client';

import {
  forwardRef,
  createContext,
  useContext,
  useState,
  useRef,
  useEffect,
  isValidElement,
} from 'react';
import { ChevronDown, Check } from 'lucide-react';
import { cn } from '@/lib/utils';

interface SelectContextValue {
  value?: string;
  onValueChange?: (value: string) => void;
  open: boolean;
  setOpen: (open: boolean) => void;
  displayValue?: string;
  setDisplayValue?: (value: string) => void;
}

const SelectContext = createContext<SelectContextValue>({
  open: false,
  setOpen: () => {},
});

interface SelectProps {
  value?: string;
  onValueChange?: (value: string) => void;
  children: React.ReactNode;
}

export function Select({ value, onValueChange, children }: SelectProps) {
  const [open, setOpen] = useState(false);
  const [displayValue, setDisplayValue] = useState<string>('');
  const containerRef = useRef<HTMLDivElement>(null);

  // Close on click outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setOpen(false);
      }
    };

    if (open) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => document.removeEventListener('mousedown', handleClickOutside);
    }
  }, [open]);

  // Close on escape key
  useEffect(() => {
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setOpen(false);
      }
    };

    if (open) {
      document.addEventListener('keydown', handleEscape);
      return () => document.removeEventListener('keydown', handleEscape);
    }
  }, [open]);

  return (
    <SelectContext.Provider
      value={{ value, onValueChange, open, setOpen, displayValue, setDisplayValue }}
    >
      <div ref={containerRef} className="relative">
        {children}
      </div>
    </SelectContext.Provider>
  );
}

interface SelectTriggerProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  children: React.ReactNode;
}

export const SelectTrigger = forwardRef<HTMLButtonElement, SelectTriggerProps>(
  ({ className, children, ...props }, ref) => {
    const { open, setOpen } = useContext(SelectContext);

    return (
      <button
        ref={ref}
        type="button"
        role="combobox"
        aria-expanded={open}
        onClick={() => setOpen(!open)}
        className={cn(
          'flex h-10 w-full items-center justify-between rounded-md border border-slate-600 bg-slate-800/50 px-3 py-2 text-sm text-slate-200',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2 focus-visible:ring-offset-slate-900',
          'disabled:cursor-not-allowed disabled:opacity-50',
          'transition-colors hover:border-slate-500',
          className
        )}
        {...props}
      >
        {children}
        <ChevronDown
          className={cn(
            'ml-2 h-4 w-4 shrink-0 opacity-50 transition-transform',
            open && 'rotate-180'
          )}
        />
      </button>
    );
  }
);

SelectTrigger.displayName = 'SelectTrigger';

interface SelectValueProps {
  placeholder?: string;
}

export function SelectValue({ placeholder }: SelectValueProps) {
  const { displayValue, value } = useContext(SelectContext);
  // Show display value if available, otherwise fall back to value or placeholder
  const text = displayValue || value || placeholder;
  return (
    <span className={cn('truncate', !displayValue && !value && 'text-slate-500')}>{text}</span>
  );
}

interface SelectContentProps {
  children: React.ReactNode;
  className?: string;
}

export function SelectContent({ children, className }: SelectContentProps) {
  const { open } = useContext(SelectContext);

  if (!open) return null;

  return (
    <div
      className={cn(
        'absolute z-50 mt-1 max-h-60 w-full overflow-auto rounded-md border border-slate-600 bg-slate-800 py-1 shadow-lg',
        'animate-in fade-in-0 zoom-in-95 slide-in-from-top-2',
        className
      )}
    >
      {children}
    </div>
  );
}

interface SelectItemProps {
  value: string;
  children: React.ReactNode;
  className?: string;
}

export function SelectItem({ value, children, className }: SelectItemProps) {
  const {
    value: selectedValue,
    onValueChange,
    setOpen,
    setDisplayValue,
  } = useContext(SelectContext);
  const isSelected = value === selectedValue;
  const itemRef = useRef<HTMLDivElement>(null);

  // Extract text content from children for display value
  const getTextContent = (node: React.ReactNode): string => {
    if (typeof node === 'string') return node;
    if (typeof node === 'number') return String(node);
    if (Array.isArray(node)) return node.map(getTextContent).join('');
    if (isValidElement(node)) {
      const element = node as React.ReactElement<{ children?: React.ReactNode }>;
      return getTextContent(element.props.children);
    }
    return '';
  };

  // Update display value when this item is selected
  useEffect(() => {
    if (isSelected && setDisplayValue) {
      const text = getTextContent(children);
      setDisplayValue(text);
    }
  }, [isSelected, children, setDisplayValue]);

  const handleClick = () => {
    onValueChange?.(value);
    setOpen(false);
  };

  return (
    <div
      ref={itemRef}
      role="option"
      aria-selected={isSelected}
      onClick={handleClick}
      className={cn(
        'relative flex cursor-pointer select-none items-center px-3 py-2 text-sm text-slate-200',
        'hover:bg-slate-700 focus:bg-slate-700',
        'transition-colors',
        isSelected && 'bg-indigo-600 hover:bg-indigo-500',
        className
      )}
    >
      <span className="flex-1">{children}</span>
      {isSelected && <Check className="ml-2 h-4 w-4 shrink-0" />}
    </div>
  );
}
