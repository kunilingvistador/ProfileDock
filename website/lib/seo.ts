import type { Metadata } from "next";

export type SiteLanguage = "ru" | "en";

export const siteURL = "https://kunilingvistador.github.io/ProfileDock/";
export const repositoryURL = "https://github.com/kunilingvistador/ProfileDock";
// GitHub's /releases/latest excludes prereleases; the catalog works for betas.
export const releaseURL = `${repositoryURL}/releases`;

export const languageURLs: Record<SiteLanguage, string> = {
  ru: siteURL,
  en: `${siteURL}en/`,
};

const descriptions = {
  ru: {
    title: "ProfileDock — ярлыки профилей Chrome в Dock на Mac",
    description:
      "Переключайте окна профилей Chrome на Mac через отдельные ярлыки в Dock и горячие клавиши. Свои фотографии и значки. Бесплатно, с открытым кодом.",
    imageAlt: "ProfileDock: узнаваемые ярлыки для открытых окон Chrome в Dock на Mac",
    locale: "ru_RU",
    alternateLocale: "en_US",
  },
  en: {
    title: "ProfileDock — Chrome Profile Shortcuts for Mac",
    description:
      "Switch Chrome profile windows on Mac with separate Dock shortcuts and global hotkeys. Custom photos and icons for your existing windows. Free and open source.",
    imageAlt: "ProfileDock: familiar Dock shortcuts for existing Chrome windows on Mac",
    locale: "en_US",
    alternateLocale: "ru_RU",
  },
} satisfies Record<SiteLanguage, Record<string, string>>;

export type ContentMetadata = {
  title: string;
  description: string;
  /** Relative to each language's home URL, with a trailing slash. */
  path: string;
  article?: boolean;
};

export function metadataFor(language: SiteLanguage, content?: ContentMetadata): Metadata {
  const copy = { ...descriptions[language], ...content };
  const urls = {
    ru: new URL(content?.path ?? "", languageURLs.ru).href,
    en: new URL(content?.path ?? "", languageURLs.en).href,
  };
  const image = `${siteURL}social-preview.png`;
  return {
    metadataBase: new URL(siteURL),
    title: copy.title,
    description: copy.description,
    applicationName: "ProfileDock",
    verification: { google: "myorIcY7TEsKKiQC5rc_fySB15tRPSfyGuDogpgtzfI" },
    alternates: {
      canonical: urls[language],
      languages: { ru: urls.ru, en: urls.en, "x-default": urls.ru },
    },
    robots: { index: true, follow: true, "max-image-preview": "large" },
    icons: { icon: { url: `${siteURL}icon.svg`, type: "image/svg+xml" } },
    openGraph: {
      type: content?.article ? "article" : "website",
      siteName: "ProfileDock",
      url: urls[language],
      title: copy.title,
      description: copy.description,
      locale: copy.locale,
      alternateLocale: [copy.alternateLocale],
      images: [{ url: image, alt: copy.imageAlt, width: 1200, height: 630 }],
      ...(content?.article ? { publishedTime: "2026-09-09", modifiedTime: "2026-09-09" } : {}),
    },
    twitter: {
      card: "summary_large_image",
      title: copy.title,
      description: copy.description,
      images: [{ url: image, alt: copy.imageAlt }],
    },
  };
}

export function guideDataFor(language: SiteLanguage, content: ContentMetadata) {
  const url = new URL(content.path, languageURLs[language]).href;
  const hub = new URL("guides/", languageURLs[language]).href;
  const items = [
    { "@type": "ListItem", position: 1, name: "ProfileDock", item: languageURLs[language] },
    { "@type": "ListItem", position: 2, name: language === "ru" ? "Инструкции" : "Guides", item: hub },
    ...(content.article ? [{ "@type": "ListItem", position: 3, name: content.title, item: url }] : []),
  ];
  return {
    "@context": "https://schema.org",
    "@graph": [
      { "@type": "BreadcrumbList", "@id": `${url}#breadcrumbs`, itemListElement: items },
      {
        "@type": content.article ? "Article" : "CollectionPage",
        "@id": `${url}#${content.article ? "article" : "page"}`,
        url,
        name: content.title,
        description: content.description,
        inLanguage: language,
        isAccessibleForFree: true,
        ...(content.article ? {
          headline: content.title,
          datePublished: "2026-09-09",
          dateModified: "2026-09-09",
          mainEntityOfPage: { "@type": "WebPage", "@id": url },
          image: `${siteURL}app-preview.jpg`,
          publisher: { "@type": "Organization", name: "ProfileDock", url: siteURL },
        } : { breadcrumb: { "@id": `${url}#breadcrumbs` } }),
      },
    ],
  };
}

export function applicationDataFor(language: SiteLanguage) {
  return {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "@id": `${siteURL}#application`,
    name: "ProfileDock",
    url: languageURLs[language],
    description: descriptions[language].description,
    operatingSystem: "macOS 13 or later",
    applicationCategory: "UtilitiesApplication",
    isAccessibleForFree: true,
    inLanguage: language,
    license: `${repositoryURL}/blob/main/LICENSE`,
    sameAs: repositoryURL,
    downloadUrl: releaseURL,
    offers: { "@type": "Offer", price: 0, priceCurrency: "USD", url: releaseURL },
    // No ratings or reviews are published yet. Do not invent them for a rich result.
  };
}

export function serializeJSONLD(value: unknown): string {
  return JSON.stringify(value).replace(/</g, "\\u003c");
}
