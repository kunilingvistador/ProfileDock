import { metadataFor } from '@/lib/seo';
import '../globals.css';

export const metadata = metadataFor('ru');

export default function RussianLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="ru"><body>{children}</body></html>;
}
