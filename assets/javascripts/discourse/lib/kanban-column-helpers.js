import { i18n } from "discourse-i18n";

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
