import { handleActions } from "redux-actions";

const initialState = {
  language: "de-DE"
};

const normalizeLanguage = value => {
  if (value === "de" || value === "de-DE") return "de-DE";
  return "en-US";
};

const setLanguage = (state, action) => ({
  ...state,
  language: normalizeLanguage(action.payload)
});

const setPersistentUI = (state, action) => {
  const language = action.payload?.locale?.language;
  if (!language) return state;
  return { ...state, language: normalizeLanguage(language) };
};

export default handleActions(
  {
    SET_LANGUAGE: setLanguage,
    SET_PERSISTENT_UI: setPersistentUI
  },
  initialState
);
