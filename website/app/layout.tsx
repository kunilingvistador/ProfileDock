import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = {
  title: 'ProfileDock — своё окно Chrome в один клик',
  description: 'Бесплатные ярлыки для открытых окон Chrome на macOS. Свои значки, сохранённые вкладки и открытый исходный код.',
  metadataBase: new URL('https://kunilingvistador.github.io/ProfileDock/'),
  icons: { icon: '/ProfileDock/icon.svg' },
};
export default function RootLayout({children}: Readonly<{children: React.ReactNode}>) {
  return <html lang="ru"><body>{children}</body></html>;
}
