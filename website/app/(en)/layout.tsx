import { metadataFor } from '@/lib/seo';
import '../globals.css';

export const metadata = metadataFor('en');

export default function EnglishLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}<script src="/ProfileDock/analytics.js" defer /></body></html>;
}
