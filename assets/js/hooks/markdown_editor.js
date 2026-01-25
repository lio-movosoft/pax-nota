/**
 * MarkdownEditor Hook
 *
 * Manages a block-based markdown editor where each block can be focused
 * and edited as raw markdown. Blocks are rendered as HTML when not focused,
 * and switch to a textarea when the user clicks on them.
 *
 * Key behaviors:
 * - Click to focus: clicking a block switches it to edit mode
 * - Cursor positioning: cursor lands at the character nearest to click location
 * - Keyboard navigation: arrow keys move between blocks when at boundaries
 * - Content sync: changes are debounced and pushed to LiveView
 * - New blocks: Enter key creates a new paragraph after current block
 */

const MarkdownEditor = {
  mounted() {
    this.handleInput = this.handleInput.bind(this);
    this.handleMouseDown = this.handleMouseDown.bind(this);
    this.handleMouseUp = this.handleMouseUp.bind(this);
    this.handleKeydown = this.handleKeydown.bind(this);

    this.el.addEventListener("input", this.handleInput);
    this.el.addEventListener("mousedown", this.handleMouseDown);
    this.el.addEventListener("mouseup", this.handleMouseUp);
    this.el.addEventListener("keydown", this.handleKeydown);

    // The block being targeted for focus (captured on mousedown, used on mouseup).
    // null when not in the middle of a click operation.
    this.targetBlock = null;

    // LiveView pushes this event when a block should be focused programmatically
    // (e.g., after creating a new block with Enter, or arrow key navigation)
    this.handleEvent("focus_block", ({ block_id }) => {
      this.focusBlock(block_id, 0);
    });

    // LiveView pushes this event when a block should be focused at a specific offset
    // (e.g., after merging blocks with Backspace)
    this.handleEvent("focus_block_at", ({ block_id, offset }) => {
      this.focusBlock(block_id, offset);
    });
  },

  destroyed() {
    this.el.removeEventListener("input", this.handleInput);
    this.el.removeEventListener("mousedown", this.handleMouseDown);
    this.el.removeEventListener("mouseup", this.handleMouseUp);
    this.el.removeEventListener("keydown", this.handleKeydown);
  },

  /**
   * Captures the target block BEFORE blur fires on the current block.
   * Event sequence: mousedown -> blur (on old) -> mouseup -> focus (on new)
   * By storing the target in mousedown, we ensure we know where the user
   * clicked even after the DOM updates from the blur event.
   */
  handleMouseDown(event) {
    const blockEl = event.target.closest("[data-block-id]");
    if (!blockEl) return;

    // If clicking the already-focused block, let native cursor behavior work
    const isFocused = blockEl.dataset.focused === "true";
    if (isFocused) {
      this.targetBlock = null;
      return;
    }

    this.targetBlock = blockEl;
  },

  /**
   * Completes the block focus operation started in mousedown.
   * At this point, the browser selection is set to where the user clicked,
   * so we can calculate the character offset for cursor positioning.
   */
  handleMouseUp() {
    if (!this.targetBlock) return;

    const blockEl = this.targetBlock;
    const blockId = blockEl.dataset.blockId;
    this.targetBlock = null;

    // Calculate where in the text the user clicked
    const offset = this.getClickOffset(blockEl);

    // Tell LiveView to focus this block (updates focused_block_id assign).
    // Note: handleMouseDown already skips focused blocks, so this only fires
    // when switching to a different block - no need for additional deduplication.
    this.pushEvent("block_selected", {
      block_id: blockId,
      offset: offset,
    });

    // Focus the textarea that will appear after LiveView re-renders
    this.focusBlock(blockId, offset);
  },

  /**
   * Calculates the character offset within a block's text content
   * based on where the user clicked.
   *
   * Only counts text within [data-inline-id] elements to avoid counting
   * HTML whitespace between tags. Walks the DOM to find which inline
   * element contains the click, then accumulates character positions.
   */
  getClickOffset(blockEl) {
    const selection = window.getSelection();
    if (!selection.rangeCount) return 0;

    const range = selection.getRangeAt(0);
    const clickNode = range.startContainer;
    const clickOffset = range.startOffset;

    if (!blockEl.contains(clickNode)) {
      return 0;
    }

    const inlineEls = blockEl.querySelectorAll("[data-inline-id]");
    let totalOffset = 0;

    for (const inlineEl of inlineEls) {
      if (inlineEl.contains(clickNode)) {
        // Click is within this inline element - walk its text nodes
        const walker = document.createTreeWalker(
          inlineEl,
          NodeFilter.SHOW_TEXT,
          null,
          false,
        );

        let node;
        while ((node = walker.nextNode())) {
          if (node === clickNode) {
            totalOffset += clickOffset;
            return totalOffset;
          }
          totalOffset += node.textContent.length;
        }
        return totalOffset;
      }

      // Click wasn't in this inline, add its full length and continue
      totalOffset += inlineEl.textContent.length;
    }

    return 0;
  },

  /**
   * Debounces content changes and syncs to LiveView.
   * Updates are sent 150ms after the user stops typing.
   */
  handleInput(event) {
    const target = event.target;
    if (!target.hasAttribute("data-block-input")) return;

    const blockEl = target.closest("[data-block-id]");
    if (!blockEl) return;

    const blockId = blockEl.dataset.blockId;

    clearTimeout(this.inputTimeout);
    this.inputTimeout = setTimeout(() => {
      this.pushEvent("block_content_changed", {
        block_id: blockId,
        content: target.value,
      });
    }, 150);
  },

  /**
   * Handles keyboard shortcuts:
   * - Enter (without Shift): Create new paragraph after current block
   * - ArrowUp at first line: Navigate to previous block
   * - ArrowDown at last line: Navigate to next block
   */
  handleKeydown(event) {
    const target = event.target;
    if (!target.hasAttribute("data-block-input")) return;

    const blockEl = target.closest("[data-block-id]");
    if (!blockEl) return;

    const blockId = blockEl.dataset.blockId;

    // Enter splits the block at cursor position (Shift+Enter allows normal newline)
    // Do nothing on empty blocks or when cursor is at the beginning
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();

      const cursorPosition = target.selectionStart;

      if (target.value.trim() === "" || cursorPosition === 0) {
        return;
      }

      this.pushEvent("split_block", {
        block_id: blockId,
        cursor_position: cursorPosition,
        content: target.value,
      });

      return;
    }

    // ArrowUp navigates to previous block
    if (event.key === "ArrowUp") {
      event.preventDefault();

      this.pushEvent("blur_block", {
        block_id: blockId,
        value: target.value,
      });

      this.pushEvent("navigate_block", {
        block_id: blockId,
        direction: "up",
      });
      return;
    }

    // ArrowDown at last line navigates to next block
    if (event.key === "ArrowDown") {
      event.preventDefault();

      this.pushEvent("blur_block", {
        block_id: blockId,
        value: target.value,
      });

      this.pushEvent("navigate_block", {
        block_id: blockId,
        direction: "down",
      });
      return;
    }

    // Backspace at beginning of block merges with previous block
    if (
      event.key === "Backspace" &&
      target.selectionStart === 0 &&
      target.selectionEnd === 0
    ) {
      event.preventDefault();

      this.pushEvent("merge_with_previous", {
        block_id: blockId,
        content: target.value,
      });
      return;
    }
  },

  /**
   * Focuses a block's textarea and positions the cursor.
   * Uses retries because LiveView may not have rendered the textarea yet.
   */
  focusBlock(blockId, offset = 0) {
    const tryFocus = () => {
      const input = this.el.querySelector(
        `[data-block-id="${blockId}"] [data-block-input]`,
      );
      if (input) {
        input.focus();
        input.setSelectionRange(offset, offset);
        return true;
      }
      return false;
    };

    if (tryFocus()) return;

    // Wait for LiveView DOM update, then retry
    requestAnimationFrame(() => {
      if (tryFocus()) return;
      setTimeout(() => tryFocus(), 50);
    });
  },
};

export default MarkdownEditor;
