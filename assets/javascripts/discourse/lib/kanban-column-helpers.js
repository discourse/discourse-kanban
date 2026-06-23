import { trustHTML } from "@ember/template";
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

// Single source of truth for the kanban column palette. Each value is a CSS
// light-dark() pair applied inline via columnColorVariable(), mirroring how core
// applies --category-color. Ruby only format-validates the stored key and SCSS
// just reads var(--column-color), so this constant is the only place to edit.
export const COLUMN_COLORS = {
  purple: "light-dark(#c97cf4, #803fa5)",
  orange: "light-dark(#fca700, #9e4c00)",
  blue: "light-dark(#669df1, #1558bc)",
  red: "light-dark(#f87168, #ae2e24)",
  lime: "light-dark(#94c748, #4c6b1f)",
  green: "light-dark(#4bce97, #216e4e)",
  pink: "light-dark(#e774bb, #943d73)",
  yellow: "light-dark(#ddb30e, #614a05)",
  teal: "light-dark(#6cc3e0, #206a83)",
};

// Mirrors core's categoryColorVariable: formats a column color key into an
// inline custom property so markup styles itself via var(--column-color).
export function columnColorVariable(color) {
  return trustHTML(`--column-color: ${COLUMN_COLORS[color] ?? "transparent"};`);
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
