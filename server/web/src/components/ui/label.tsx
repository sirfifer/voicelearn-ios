import { forwardRef } from 'react';
import { cn } from '@/lib/utils';

interface LabelProps extends React.LabelHTMLAttributes<HTMLLabelElement> {
  children: React.ReactNode;
}

export const Label = forwardRef<HTMLLabelElement, LabelProps>(
  ({ className, children, ...props }, ref) => {
    return (
      <label ref={ref} className={cn('text-sm font-medium text-slate-300', className)} {...props}>
        {children}
      </label>
    );
  }
);

Label.displayName = 'Label';
