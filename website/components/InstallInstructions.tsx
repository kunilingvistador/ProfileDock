import type { SiteLanguage } from "@/lib/seo";

export const installCopy = {
  ru: {
    title: "Как установить ProfileDock",
    jump: "Как установить",
    first: "Распакуйте ZIP и перенесите ProfileDock.app в папку «Программы».",
    second: "Откройте ProfileDock из папки «Программы».",
    third: "Нажмите «Подключить Chrome» и разрешите управление Google Chrome в запросе macOS.",
    warning: "Бета без нотариализации Apple. Если macOS не может проверить разработчика, после попытки запуска откройте «Системные настройки → Конфиденциальность и безопасность». Подтверждайте запуск только для доверенной копии с этой страницы.",
    help: "Инструкция Apple",
    helpURL: "https://support.apple.com/ru-ru/102445",
  },
  en: {
    title: "How to install ProfileDock",
    jump: "How to install",
    first: "Unzip the download and move ProfileDock.app to Applications.",
    second: "Open ProfileDock from Applications.",
    third: "Click “Connect Chrome” and allow ProfileDock to control Google Chrome when macOS asks.",
    warning: "Apple hasn’t notarized this beta. If macOS can’t verify the developer, try opening the app and then go to System Settings → Privacy & Security. Only approve a trusted copy from this page.",
    help: "Apple’s instructions",
    helpURL: "https://support.apple.com/en-us/102445",
  },
} satisfies Record<SiteLanguage, Record<string, string>>;

export default function InstallInstructions({ language }: { language: SiteLanguage }) {
  const t = installCopy[language];
  return <div className="install-instructions">
    <ol>
      <li>{t.first}</li>
      <li>{t.second}</li>
      <li>{t.third}</li>
    </ol>
    <p>{t.warning} <a href={t.helpURL}>{t.help}</a></p>
  </div>;
}
