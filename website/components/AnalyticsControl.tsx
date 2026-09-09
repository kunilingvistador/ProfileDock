"use client";

import { useEffect, useState } from "react";

export default function AnalyticsControl({ language }: { language: "ru" | "en" }) {
  const [enabled, setEnabled] = useState<boolean | null>(null);
  useEffect(() => {
    const update = (event: Event) => setEnabled((event as CustomEvent<boolean>).detail);
    document.addEventListener("profiledock:analytics-state", update);
    document.dispatchEvent(new Event("profiledock:analytics-query"));
    return () => document.removeEventListener("profiledock:analytics-state", update);
  }, []);
  const label = enabled === null
    ? (language === "ru" ? "Настройка аналитики…" : "Loading analytics setting…")
    : language === "ru"
      ? (enabled ? "Отключить аналитику в этом браузере" : "Включить аналитику в этом браузере")
      : (enabled ? "Turn off analytics in this browser" : "Turn on analytics in this browser");
  return <button className="analytics-toggle" disabled={enabled === null}
    onClick={() => document.dispatchEvent(new Event("profiledock:analytics-toggle"))}>{label}</button>;
}
