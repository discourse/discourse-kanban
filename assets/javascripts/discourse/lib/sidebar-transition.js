import { schedule } from "@ember/runloop";

export function withSidebarViewTransition(callback) {
  if (!document.startViewTransition) {
    callback();
    return;
  }

  document.startViewTransition(() => {
    callback();
    return new Promise((resolve) => schedule("afterRender", resolve));
  });
}
