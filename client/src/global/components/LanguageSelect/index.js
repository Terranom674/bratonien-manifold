import React from "react";
import { connect } from "react-redux";
import { useDispatch } from "react-redux";
import { useTranslation } from "react-i18next";
import { uiLocaleActions } from "actions";
import { Select } from "global/components/atomic/form";

const normalizeLanguage = value => {
  if (value === "en" || value === "en-US") return "en-US";
  return "de-DE";
};

function LanguageSelect({ language, label, instructions }) {
  const { t } = useTranslation();
  const dispatch = useDispatch();
  const lang = normalizeLanguage(language);

  const handleChange = event => {
    const newLang = normalizeLanguage(event.target?.value);
    if (newLang === lang) return;
    dispatch(uiLocaleActions.setLanguage(newLang));
  };

  return (
    <Select
      label={label || t("localize-content")}
      instructions={instructions}
      value={lang}
      options={[
        {
          value: "de-DE",
          label: t("locales.de-DE")
        },
        {
          value: "en-US",
          label: t("locales.en-US")
        }
      ]}
      onChange={handleChange}
      preIcon="languageGlobe24"
    />
  );
}

LanguageSelect.mapStateToProps = state => ({
  language: state.ui.persistent.locale.language
});

LanguageSelect.displayName = "Global.LanguageSelect";
export default connect(LanguageSelect.mapStateToProps)(LanguageSelect);
