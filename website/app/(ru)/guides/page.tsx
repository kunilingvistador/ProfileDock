import { GuideHub } from "@/components/Guides";
import { guideMetadata } from "@/lib/guides";
import { metadataFor } from "@/lib/seo";

export const dynamic = "force-static";
export const metadata = metadataFor("ru", guideMetadata("ru"));

export default function Page() { return <GuideHub language="ru" />; }
