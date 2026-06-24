import { trustHTML } from "@ember/template";
import { isValidHex, normalizeHex } from "discourse/lib/color-transformations";
import { i18n } from "discourse-i18n";

export const COLUMN_SORT_OPTIONS = [
  {
    id: "priority",
    name: i18n("discourse_kanban.manage.columns.default_sort_priority"),
  },
  {
    id: "recency",
    name: i18n("discourse_kanban.manage.columns.default_sort_recency"),
  },
];

export const STATUS_OPTIONS = [
  {
    id: "open",
    name: i18n("discourse_kanban.manage.columns.move_to_status_open"),
  },
  {
    id: "closed",
    name: i18n("discourse_kanban.manage.columns.move_to_status_closed"),
  },
];

// Suggested palette fed to the FormKit color control as @colors. Values are
// bare 6-digit hexes (no leading "#"), matching how core stores category colors.
// These are only presets — the control also accepts any custom hex.
export const COLUMN_COLORS = [
  "C97CF4",
  "FCA700",
  "669DF1",
  "F87168",
  "94C748",
  "4BCE97",
  "E774BB",
  "DDB30E",
  "6CC3E0",
];

// True when a stored color is a usable hex; drives the --has-color modifier.
export function hasColumnColor(color) {
  return !!isValidHex(color);
}

// Relative luminance of a 6-digit hex (0–1), used to pick contrasting text.
function luminance(hex) {
  const r = parseInt(hex.slice(0, 2), 16);
  const g = parseInt(hex.slice(2, 4), 16);
  const b = parseInt(hex.slice(4, 6), 16);
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
}

// Mirrors core's categoryColorVariable: turns a stored hex into inline custom
// properties — the fill plus contrasting text colors so the header stays
// readable for any color, preset or custom. The title sits on a chip that
// darkens the fill by ~30%, so it gets its own text color judged against that
// darker background (and so trends lighter than the count on the bare fill).
export function columnColorVariable(color) {
  if (!isValidHex(color)) {
    return trustHTML("--column-color: transparent;");
  }
  const hex = normalizeHex(color);
  const lum = luminance(hex);
  const text = lum > 0.5 ? "#000000" : "#ffffff";
  const titleText = lum * 0.7 > 0.5 ? "#000000" : "#ffffff";
  return trustHTML(
    `--column-color: #${hex}; --column-text-color: ${text}; --column-title-text-color: ${titleText};`
  );
}

export const ASSIGNED_OPTIONS = [
  {
    id: "nobody",
    name: i18n("discourse_kanban.manage.columns.move_to_assigned_unassign"),
  },
  {
    id: "_user",
    name: i18n("discourse_kanban.manage.columns.move_to_assigned_user"),
  },
];

export function tagToArray(tag) {
  return tag ? [tag] : [];
}

export function assignedMode(value) {
  if (!value) {
    return "";
  }
  if (value === "nobody") {
    return "nobody";
  }
  return "_user";
}

export function assignedUserValue(value) {
  if (!value || value === "nobody" || value === "_user") {
    return [];
  }
  return [value];
}
