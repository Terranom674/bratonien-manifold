import { updateI18n } from "utils/i18n";

export default function syncLocale(store) {
  let lastLanguage = null;

  return () => {
    const language = store.getState()?.ui?.persistent?.locale?.language || "de-DE";
    if (language === lastLanguage) return;

    lastLanguage = language;
    updateI18n(language);
  };
}
