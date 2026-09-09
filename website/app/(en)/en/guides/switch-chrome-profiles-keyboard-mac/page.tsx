import { GuideArticle } from "@/components/Guides";
import { guideMetadata } from "@/lib/guides";
import { metadataFor } from "@/lib/seo";

const slug = "switch-chrome-profiles-keyboard-mac";
export const dynamic = "force-static";
export const metadata = metadataFor("en", guideMetadata("en", slug));

export default function Page() { return <GuideArticle language="en" slug={slug} />; }
