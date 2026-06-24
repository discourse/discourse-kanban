import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  columnColorVariable,
  hasColumnColor,
} from "discourse/plugins/discourse-kanban/discourse/lib/kanban-column-helpers";

module(
  "Discourse Kanban | Unit | Lib | kanban-column-helpers",
  function (hooks) {
    setupTest(hooks);

    test("hasColumnColor recognizes valid hex values only", function (assert) {
      assert.true(hasColumnColor("1a2b3c"), "a 6-digit hex has a color");
      assert.true(hasColumnColor("f0a"), "a 3-digit hex has a color");
      assert.false(hasColumnColor(null), "no value has no color");
      assert.false(hasColumnColor(""), "empty has no color");
      assert.false(hasColumnColor("nope!"), "a malformed value has no color");
    });

    test("columnColorVariable emits the fill plus contrasting text colors", function (assert) {
      assert.strictEqual(
        columnColorVariable("1a2b3c").toString(),
        "--column-color: #1a2b3c; --column-text-color: #ffffff; --column-title-text-color: #ffffff;",
        "a dark color gets white text everywhere"
      );
      assert.strictEqual(
        columnColorVariable("ddb30e").toString(),
        "--column-color: #ddb30e; --column-text-color: #000000; --column-title-text-color: #ffffff;",
        "a light color gets black text on the fill but lighter text on the darker title chip"
      );
      assert.strictEqual(
        columnColorVariable("f0a").toString(),
        "--column-color: #ff00aa; --column-text-color: #ffffff; --column-title-text-color: #ffffff;",
        "short hexes are expanded"
      );
      assert.strictEqual(
        columnColorVariable(null).toString(),
        "--column-color: transparent;",
        "unset/invalid colors are transparent with no text color"
      );
    });
  }
);
