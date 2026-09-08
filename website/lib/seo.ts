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
      "Добавьте профили Chrome отдельными ярлыками в Dock на Mac. Свои фотографии и значки, переключение на выбранные открытые окна. Бесплатно, с открытым кодом.",
    imageAlt: "ProfileDock: узнаваемые ярлыки для открытых окон Chrome в Dock на Mac",
    locale: "ru_RU",
    alternateLocale: "en_US",
  },
  en: {
    title: "ProfileDock — Chrome Profile Shortcuts for Mac",
    description:
      "Give each Chrome profile its own Mac Dock shortcut with a custom photo or icon. Bring your chosen open window forward in one click. Free and open source.",
    imageAlt: "ProfileDock: familiar Dock shortcuts for existing Chrome windows on Mac",
    locale: "en_US",
    alternateLocale: "ru_RU",
  },
} satisfies Record<SiteLanguage, Record<string, string>>;

export function metadataFor(language: SiteLanguage): Metadata {
  const copy = descriptions[language];
  const image = `${siteURL}social-preview.png`;
  return {
    metadataBase: new URL(siteURL),
    title: copy.title,
    description: copy.description,
    applicationName: "ProfileDock",
    alternates: {
      canonical: languageURLs[language],
      languages: { ru: languageURLs.ru, en: languageURLs.en, "x-default": languageURLs.ru },
    },
    robots: { index: true, follow: true, "max-image-preview": "large" },
    icons: { icon: { url: `${siteURL}icon.svg`, type: "image/svg+xml" } },
    openGraph: {
      type: "website",
      siteName: "ProfileDock",
      url: languageURLs[language],
      title: copy.title,
      description: copy.description,
      locale: copy.locale,
      alternateLocale: [copy.alternateLocale],
      images: [{ url: image, alt: copy.imageAlt, width: 1200, height: 630 }],
    },
    twitter: {
      card: "summary_large_image",
      title: copy.title,
      description: copy.description,
      images: [{ url: image, alt: copy.imageAlt }],
    },
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
