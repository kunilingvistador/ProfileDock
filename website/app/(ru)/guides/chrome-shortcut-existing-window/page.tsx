import { GuideArticle } from "@/components/Guides";
import { guideMetadata } from "@/lib/guides";
import { metadataFor } from "@/lib/seo";

const slug = "chrome-shortcut-existing-window";
export const dynamic = "force-static";
export const metadata = metadataFor("ru", guideMetadata("ru", slug));

export default function Page() { return <GuideArticle language="ru" slug={slug} />; }
