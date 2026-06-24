import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  columnColorVariable,
  customColorVariable,
  hasColumnColor,
  isCustomColor,
  isPresetColor,
} from "discourse/plugins/discourse-kanban/discourse/lib/kanban-column-helpers";

module(
  "Discourse Kanban | Unit | Lib | kanban-column-helpers",
  function (hooks) {
    setupTest(hooks);

    test("classifies preset keys, custom hexes, and empty values", function (assert) {
      assert.true(isPresetColor("purple"), "a known key is a preset");
      assert.false(isPresetColor("1a2b3c"), "a hex is not a preset");
      assert.false(isPresetColor(null), "null is not a preset");

      assert.true(isCustomColor("1a2b3c"), "a 6-digit hex is a custom color");
      assert.true(isCustomColor("f0a"), "a 3-digit hex is a custom color");
      assert.false(isCustomColor("purple"), "a preset key is not custom");
      assert.false(isCustomColor("nope!"), "a malformed value is not custom");
      assert.false(isCustomColor(null), "null is not custom");

      assert.true(
        hasColumnColor("purple"),
        "a preset counts as having a color"
      );
      assert.true(
        hasColumnColor("1a2b3c"),
        "a custom hex counts as having a color"
      );
      assert.false(hasColumnColor(null), "no value has no color");
      assert.false(hasColumnColor("nope!"), "a malformed value has no color");
    });

    test("columnColorVariable resolves to the right CSS value", function (assert) {
      assert.strictEqual(
        columnColorVariable("purple").toString(),
        "--column-color: light-dark(#c97cf4, #803fa5);",
        "presets resolve to their light-dark() pair"
      );
      assert.strictEqual(
        columnColorVariable("1a2b3c").toString(),
        "--column-color: #1a2b3c;",
        "custom hexes resolve to a # value"
      );
      assert.strictEqual(
        columnColorVariable("f0a").toString(),
        "--column-color: #ff00aa;",
        "short hexes are expanded"
      );
      assert.strictEqual(
        columnColorVariable(null).toString(),
        "--column-color: transparent;",
        "unset/unknown colors are transparent"
      );
    });

    test("customColorVariable reflects the working hex or a neutral fallback", function (assert) {
      assert.strictEqual(
        customColorVariable("1a2b3c").toString(),
        "--column-color: #1a2b3c;",
        "a chosen hex fills the swatch"
      );
      assert.strictEqual(
        customColorVariable(null).toString(),
        "--column-color: var(--primary-low);",
        "an empty slot uses a neutral fill"
      );
    });
  }
);
