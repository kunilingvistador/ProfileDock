import Landing from '@/components/Landing';
import { applicationDataFor, serializeJSONLD } from '@/lib/seo';

export const dynamic = 'force-static';

export default function RussianPage() {
  return <>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: serializeJSONLD(applicationDataFor('ru')) }} />
    <Landing initialLanguage="ru" />
  </>;
}
