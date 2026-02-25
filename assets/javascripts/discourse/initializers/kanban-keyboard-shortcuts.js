import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";

const SELECTED_CLASS = "kanban-card--kb-selected";
const BOARD_SELECTED_CLASS = "kanban-board-card--kb-selected";

function isOnKanbanRoute(container) {
  const router = container.lookup("service:router");
  return router.currentRouteName?.startsWith("kanbanBoard");
}

function isInputFocused() {
  const el = document.activeElement;
  if (!el) {
    return false;
  }
  const tag = el.tagName;
  return (
    tag === "INPUT" ||
    tag === "TEXTAREA" ||
    tag === "SELECT" ||
    el.isContentEditable
  );
}

function getColumns() {
  return [...document.querySelectorAll(".kanban-column")];
}

function getCards(columnEl) {
  return [...columnEl.querySelectorAll(".kanban-card")];
}

function getBoardCards() {
  return [...document.querySelectorAll(".kanban-board-card")];
}

function isOnBoardsList() {
  return document.querySelector(".kanban-boards-grid") !== null;
}

function clearSelection() {
  document
    .querySelector(`.${SELECTED_CLASS}`)
    ?.classList.remove(SELECTED_CLASS);
  document
    .querySelector(`.${BOARD_SELECTED_CLASS}`)
    ?.classList.remove(BOARD_SELECTED_CLASS);
}

function selectCard(columnEl, cardIdx) {
  clearSelection();
  const cards = getCards(columnEl);
  if (!cards.length) {
    return;
  }
  const clamped = Math.min(cardIdx, cards.length - 1);
  const card = cards[clamped];
  card.classList.add(SELECTED_CLASS);
  card.scrollIntoView({ block: "nearest", behavior: "smooth" });
}

function getCardDataId(cardEl) {
  return parseInt(cardEl.dataset.cardId, 10);
}

function getColumnDataId(columnEl) {
  const id = columnEl.dataset.columnId;
  return id ? parseInt(id, 10) : null;
}

function moveCard(container, cardId, toColumnId, afterCardId) {
  const router = container.lookup("service:router");
  const boardId = router.currentRoute?.params?.id;
  if (!boardId) {
    return Promise.reject("No board ID");
  }

  // Intentionally omit client_id so the MessageBus broadcast comes back
  // to our own client and the board viewer component re-renders.
  return ajax(`/kanban/boards/${boardId}/cards/${cardId}`, {
    type: "PUT",
    data: {
      card: {
        column_id: toColumnId,
        after_card_id: afterCardId,
      },
    },
  });
}

export default {
  name: "kanban-keyboard-shortcuts",

  initialize(container) {
    let colIndex = -1;
    let cardIndex = -1;
    let boardIndex = -1;
    let moving = false;

    function resetCursor() {
      colIndex = -1;
      cardIndex = -1;
      boardIndex = -1;
      clearSelection();
    }

    function guard() {
      return !isOnKanbanRoute(container) || isInputFocused();
    }

    function ensureCursor() {
      if (colIndex === -1) {
        colIndex = 0;
        cardIndex = 0;
        return true;
      }
      return false;
    }

    const router = container.lookup("service:router");
    router.on("routeDidChange", resetCursor);

    withPluginApi((api) => {
      // Navigation: h/l move between columns, j/k move within column

      api.addKeyboardShortcut(
        "h",
        () => {
          if (guard()) {
            return;
          }
          if (isOnBoardsList()) {
            const boards = getBoardCards();
            if (!boards.length) {
              return;
            }
            if (boardIndex === -1) {
              boardIndex = 0;
            } else if (boardIndex > 0) {
              boardIndex--;
            }
            clearSelection();
            boards[boardIndex].classList.add(BOARD_SELECTED_CLASS);
            boards[boardIndex].scrollIntoView({
              block: "nearest",
              behavior: "smooth",
            });
            return;
          }
          const columns = getColumns();
          if (!columns.length) {
            return;
          }
          if (!ensureCursor() && colIndex > 0) {
            colIndex--;
            const cards = getCards(columns[colIndex]);
            cardIndex = Math.min(cardIndex, Math.max(0, cards.length - 1));
          }
          selectCard(columns[colIndex], cardIndex);
        },
        {
          help: {
            category: "kanban",
            name: "discourse_kanban.keyboard_shortcuts.navigate_columns",
            definition: {
              keys1: ["h"],
              keys2: ["l"],
              keysDelimiter: "space",
              shortcutsDelimiter: "slash",
            },
          },
        }
      );

      api.addKeyboardShortcut("l", () => {
        if (guard()) {
          return;
        }
        if (isOnBoardsList()) {
          const boards = getBoardCards();
          if (!boards.length) {
            return;
          }
          if (boardIndex === -1) {
            boardIndex = 0;
          } else if (boardIndex < boards.length - 1) {
            boardIndex++;
          }
          clearSelection();
          boards[boardIndex].classList.add(BOARD_SELECTED_CLASS);
          boards[boardIndex].scrollIntoView({
            block: "nearest",
            behavior: "smooth",
          });
          return;
        }
        const columns = getColumns();
        if (!columns.length) {
          return;
        }
        if (!ensureCursor() && colIndex < columns.length - 1) {
          colIndex++;
          const cards = getCards(columns[colIndex]);
          cardIndex = Math.min(cardIndex, Math.max(0, cards.length - 1));
        }
        selectCard(columns[colIndex], cardIndex);
      });

      api.addKeyboardShortcut(
        "j",
        () => {
          if (guard()) {
            return;
          }
          const columns = getColumns();
          if (!columns.length) {
            return;
          }
          if (!ensureCursor()) {
            const cards = getCards(columns[colIndex]);
            if (cardIndex < cards.length - 1) {
              cardIndex++;
            }
          }
          selectCard(columns[colIndex], cardIndex);
        },
        {
          help: {
            category: "kanban",
            name: "discourse_kanban.keyboard_shortcuts.navigate_cards",
            definition: {
              keys1: ["j"],
              keys2: ["k"],
              keysDelimiter: "space",
              shortcutsDelimiter: "slash",
            },
          },
        }
      );

      api.addKeyboardShortcut("k", () => {
        if (guard()) {
          return;
        }
        const columns = getColumns();
        if (!columns.length) {
          return;
        }
        if (!ensureCursor() && cardIndex > 0) {
          cardIndex--;
        }
        selectCard(columns[colIndex], cardIndex);
      });

      // Enter: open selected card (topic link or floater detail modal)
      api.addKeyboardShortcut(
        "enter",
        () => {
          if (guard()) {
            return;
          }
          if (isOnBoardsList()) {
            const selected = document.querySelector(`.${BOARD_SELECTED_CLASS}`);
            if (selected) {
              const link = selected.querySelector("a.kanban-board-card__name");
              if (link) {
                link.click();
              }
            }
            return;
          }
          const selected = document.querySelector(`.${SELECTED_CLASS}`);
          if (!selected) {
            return;
          }
          const link = selected.querySelector("a.kanban-card__title");
          if (link) {
            link.click();
            return;
          }
          selected.click();
        },
        {
          help: {
            category: "kanban",
            name: "discourse_kanban.keyboard_shortcuts.open_card",
            definition: {
              keys1: ["enter"],
            },
          },
        }
      );

      // Escape: clear selection
      api.addKeyboardShortcut("escape", () => {
        if (guard()) {
          return;
        }
        if (
          document.querySelector(`.${SELECTED_CLASS}`) ||
          document.querySelector(`.${BOARD_SELECTED_CLASS}`)
        ) {
          resetCursor();
        }
      });

      // Shift+h/l: move card between columns
      // Shift+j/k: reorder card within column

      function afterMove(newColIndex, newCardIndex) {
        colIndex = newColIndex;
        cardIndex = newCardIndex;
        moving = false;

        // Wait for the MessageBus round-trip and Ember re-render before
        // re-selecting. The server broadcasts card_moved, the board viewer
        // handles it and updates tracked state, then Ember re-renders.
        setTimeout(() => {
          const cols = getColumns();
          if (cols[colIndex]) {
            const cards = getCards(cols[colIndex]);
            cardIndex = Math.min(cardIndex, Math.max(0, cards.length - 1));
            selectCard(cols[colIndex], cardIndex);
          }
        }, 300);
      }

      api.addKeyboardShortcut(
        "shift+l",
        () => {
          if (guard() || moving) {
            return;
          }
          const columns = getColumns();
          if (colIndex === -1 || colIndex >= columns.length - 1) {
            return;
          }
          const cards = getCards(columns[colIndex]);
          if (!cards.length || cardIndex >= cards.length) {
            return;
          }

          const cardId = getCardDataId(cards[cardIndex]);
          const toColumnId = getColumnDataId(columns[colIndex + 1]);
          if (!toColumnId) {
            return;
          }

          const targetCards = getCards(columns[colIndex + 1]);
          let afterCardId = null;
          const targetIdx = Math.min(cardIndex, targetCards.length) - 1;
          if (targetIdx >= 0) {
            afterCardId = getCardDataId(targetCards[targetIdx]);
          }

          moving = true;
          moveCard(container, cardId, toColumnId, afterCardId).then(
            () => afterMove(colIndex + 1, cardIndex),
            () => {
              moving = false;
            }
          );
        },
        {
          help: {
            category: "kanban",
            name: "discourse_kanban.keyboard_shortcuts.move_card_column",
            definition: {
              keys1: ["shift", "h"],
              keys2: ["shift", "l"],
              keysDelimiter: "plus",
              shortcutsDelimiter: "slash",
            },
          },
        }
      );

      api.addKeyboardShortcut("shift+h", () => {
        if (guard() || moving) {
          return;
        }
        const columns = getColumns();
        if (colIndex <= 0) {
          return;
        }
        const cards = getCards(columns[colIndex]);
        if (!cards.length || cardIndex >= cards.length) {
          return;
        }

        const cardId = getCardDataId(cards[cardIndex]);
        const toColumnId = getColumnDataId(columns[colIndex - 1]);
        if (!toColumnId) {
          return;
        }

        const targetCards = getCards(columns[colIndex - 1]);
        let afterCardId = null;
        const targetIdx = Math.min(cardIndex, targetCards.length) - 1;
        if (targetIdx >= 0) {
          afterCardId = getCardDataId(targetCards[targetIdx]);
        }

        moving = true;
        moveCard(container, cardId, toColumnId, afterCardId).then(
          () => afterMove(colIndex - 1, cardIndex),
          () => {
            moving = false;
          }
        );
      });

      api.addKeyboardShortcut(
        "shift+j",
        () => {
          if (guard() || moving) {
            return;
          }
          const columns = getColumns();
          if (colIndex === -1) {
            return;
          }
          const cards = getCards(columns[colIndex]);
          if (cardIndex >= cards.length - 1) {
            return;
          }

          const cardId = getCardDataId(cards[cardIndex]);
          const columnId = getColumnDataId(columns[colIndex]);
          if (!columnId) {
            return;
          }

          const afterCardId = getCardDataId(cards[cardIndex + 1]);

          moving = true;
          moveCard(container, cardId, columnId, afterCardId).then(
            () => afterMove(colIndex, cardIndex + 1),
            () => {
              moving = false;
            }
          );
        },
        {
          help: {
            category: "kanban",
            name: "discourse_kanban.keyboard_shortcuts.move_card_position",
            definition: {
              keys1: ["shift", "j"],
              keys2: ["shift", "k"],
              keysDelimiter: "plus",
              shortcutsDelimiter: "slash",
            },
          },
        }
      );

      api.addKeyboardShortcut("shift+k", () => {
        if (guard() || moving) {
          return;
        }
        const columns = getColumns();
        if (colIndex === -1 || cardIndex <= 0) {
          return;
        }
        const cards = getCards(columns[colIndex]);
        const cardId = getCardDataId(cards[cardIndex]);
        const columnId = getColumnDataId(columns[colIndex]);
        if (!columnId) {
          return;
        }

        let afterCardId = null;
        if (cardIndex >= 2) {
          afterCardId = getCardDataId(cards[cardIndex - 2]);
        }

        moving = true;
        moveCard(container, cardId, columnId, afterCardId).then(
          () => afterMove(colIndex, cardIndex - 1),
          () => {
            moving = false;
          }
        );
      });
    });
  },
};
