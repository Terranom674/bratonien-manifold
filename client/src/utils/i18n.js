import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import translations from "config/app/locale";

const normalizeLanguage = value => {
  if (value === "en" || value === "en-US") return "en-US";
  return "de-DE";
};

export const updateI18n = lang => {
  const language = normalizeLanguage(lang);
  if (i18n.language !== language) {
    i18n.changeLanguage(language);
  }
  if (typeof document !== "undefined") {
    document.documentElement.lang = language;
  }
};

i18n
  .use(initReactI18next) // passes i18n down to react-i18next
  .init({
    // debug: true,
    lng: "de-DE",
    resources: translations,
    interpolation: {
      escapeValue: false
    },
    fallbackLng: {
      default: ["de-DE", "en-US"]
    },
    react: {
      transSupportBasicHtmlNodes: true
    }
  });

export default i18n;
