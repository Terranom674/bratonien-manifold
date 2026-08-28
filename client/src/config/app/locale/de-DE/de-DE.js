/* eslint-disable import/extensions */
import base from "./json/base.json";
import shared from "./json/shared";
import de from "date-fns/locale/de";

export default {
  translation: {
    ...base,
    ...shared,
    date_fns: de
  }
};
