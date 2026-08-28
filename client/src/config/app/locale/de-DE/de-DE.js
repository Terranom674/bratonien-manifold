/* eslint-disable import/extensions */
import base from "./json/base.json";
import backend from "./json/backend";
import frontend from "./json/frontend";
import reader from "./json/reader";
import shared from "./json/shared";
import { de } from "date-fns/locale/de";

export default {
  translation: {
    ...base,
    ...backend,
    ...frontend,
    ...reader,
    ...shared,
    date_fns: de
  }
};
