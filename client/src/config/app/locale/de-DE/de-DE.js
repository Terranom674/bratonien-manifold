/* eslint-disable import/extensions */
import base from "./json/base.json";
import reader from "./json/reader";
import shared from "./json/shared";
import de from "date-fns/locale/de";

export default {
  translation: {
    ...base,
    ...reader,
    ...shared,
    date_fns: de
  }
};
