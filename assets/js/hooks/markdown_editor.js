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
 * - Wiki-link autocomplete: typing [[ triggers autocomplete dropdown
 */

const MarkdownEditor = {
  mounted() {
    this.handleInput = this.handleInput.bind(this);
    this.handleMouseDown = this.handleMouseDown.bind(this);
    this.handleMouseUp = this.handleMouseUp.bind(this);
    this.handleKeydown = this.handleKeydown.bind(this);
    this.handleDragEnter = this.handleDragEnter.bind(this);
    this.handleDragOver = this.handleDragOver.bind(this);
    this.handleDragLeave = this.handleDragLeave.bind(this);
    this.handleDrop = this.handleDrop.bind(this);

    this.el.addEventListener("input", this.handleInput);
    this.el.addEventListener("mousedown", this.handleMouseDown);
    this.el.addEventListener("mouseup", this.handleMouseUp);
    this.el.addEventListener("keydown", this.handleKeydown);
    this.el.addEventListener("dragenter", this.handleDragEnter);
    this.el.addEventListener("dragover", this.handleDragOver);
    this.el.addEventListener("dragleave", this.handleDragLeave);
    this.el.addEventListener("drop", this.handleDrop);

    // The block being targeted for focus (captured on mousedown, used on mouseup).
    // null when not in the middle of a click operation.
    this.targetBlock = null;

    // Autocomplete state - tracks the position of [[ trigger
    this.autocompleteStartPos = null;
    this.autocompleteBlockId = null;

    // Drag/drop state
    this.lastDropTarget = null;

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

    // LiveView pushes this event when a note link is selected from autocomplete
    this.handleEvent("insert_note_link", ({ block_id, note_id, title, start_pos }) => {
      const input = this.el.querySelector(
        `[data-block-id="${block_id}"] [data-block-input]`,
      );
      if (!input) return;

      const before = input.value.substring(0, start_pos);
      const after = input.value.substring(input.selectionStart);
      const linkMarkdown = `[${title}](/notes/${note_id})`;
      const newValue = before + linkMarkdown + after;
      const newCursorPos = start_pos + linkMarkdown.length;

      input.value = newValue;
      input.focus();
      input.setSelectionRange(newCursorPos, newCursorPos);

      this.autocompleteStartPos = null;
      this.autocompleteBlockId = null;

      this.pushEvent("block_content_changed", {
        block_id: block_id,
        content: newValue,
      });
    });

    // LiveView pushes this event when autocomplete is closed without selection
    this.handleEvent("autocomplete_closed", ({ block_id }) => {
      this.autocompleteStartPos = null;
      this.autocompleteBlockId = null;

      const input = this.el.querySelector(
        `[data-block-id="${block_id}"] [data-block-input]`,
      );
      if (input) {
        input.focus();
      }
    });
  },

  destroyed() {
    this.el.removeEventListener("input", this.handleInput);
    this.el.removeEventListener("mousedown", this.handleMouseDown);
    this.el.removeEventListener("mouseup", this.handleMouseUp);
    this.el.removeEventListener("keydown", this.handleKeydown);
    this.el.removeEventListener("dragenter", this.handleDragEnter);
    this.el.removeEventListener("dragover", this.handleDragOver);
    this.el.removeEventListener("dragleave", this.handleDragLeave);
    this.el.removeEventListener("drop", this.handleDrop);
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
    const blockType = blockEl.dataset.blockType;
    this.targetBlock = null;

    // Image blocks: just select them (they're not editable as text)
    if (blockType === "image") {
      this.pushEvent("block_selected", { block_id: blockId, offset: 0 });
      blockEl.focus(); // Make it focusable for keyboard events
      return;
    }

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
   * Also detects [[ trigger for wiki-link autocomplete.
   */
  handleInput(event) {
    const target = event.target;
    if (!target.hasAttribute("data-block-input")) return;

    const blockEl = target.closest("[data-block-id]");
    if (!blockEl) return;

    const blockId = blockEl.dataset.blockId;
    const cursorPos = target.selectionStart;
    const textBeforeCursor = target.value.substring(0, cursorPos);

    // Check for [[ trigger (must be typed, not already in text with closing ]])
    if (
      textBeforeCursor.endsWith("[[") &&
      this.autocompleteStartPos === null
    ) {
      const rect = target.getBoundingClientRect();
      const containerRect = this.el.parentElement.getBoundingClientRect();
      this.autocompleteStartPos = cursorPos - 2;
      this.autocompleteBlockId = blockId;

      this.pushEvent("show_autocomplete", {
        block_id: blockId,
        start_pos: this.autocompleteStartPos,
        top: rect.top - containerRect.top + 24,
        left: rect.left - containerRect.left,
      });
    }

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
   * - Backspace on image block: Delete the block
   */
  handleKeydown(event) {
    const target = event.target;

    // Handle image block deletion with Backspace or Delete
    const imageBlock = target.closest('[data-block-type="image"]');
    if (imageBlock && (event.key === "Backspace" || event.key === "Delete")) {
      event.preventDefault();
      this.pushEvent("delete_block", { block_id: imageBlock.dataset.blockId });
      return;
    }

    // Handle arrow navigation on image blocks
    if (imageBlock && (event.key === "ArrowUp" || event.key === "ArrowDown")) {
      event.preventDefault();
      this.pushEvent("navigate_block", {
        block_id: imageBlock.dataset.blockId,
        direction: event.key === "ArrowUp" ? "up" : "down",
      });
      return;
    }

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

  // === Drag/Drop Handlers ===

  hasImageFiles(event) {
    if (!event.dataTransfer?.types?.includes("Files")) return false;
    const items = Array.from(event.dataTransfer.items || []);
    return items.some((item) => item.type.startsWith("image/"));
  },

  handleDragEnter(event) {
    if (!this.hasImageFiles(event)) return;
    event.preventDefault();
    this.el.classList.add("drag-active");
  },

  handleDragOver(event) {
    if (!this.hasImageFiles(event)) return;
    event.preventDefault();

    // Find which block we're hovering over
    const blockEl = event.target.closest("[data-block-id]");
    const targetBlockId = blockEl ? blockEl.dataset.blockId : null;

    // Only update if target changed (to avoid excessive events)
    if (targetBlockId !== this.lastDropTarget) {
      this.lastDropTarget = targetBlockId;
      this.updateDropIndicator(blockEl);
      this.pushEvent("drop_image_start", { target_block_id: targetBlockId });
    }
  },

  handleDragLeave(event) {
    // Only handle if leaving the editor entirely
    if (this.el.contains(event.relatedTarget)) return;

    this.el.classList.remove("drag-active");
    this.removeDropIndicator();
    this.lastDropTarget = null;
    this.pushEvent("drop_image_cancel", {});
  },

  handleDrop(event) {
    if (!this.hasImageFiles(event)) return;
    event.preventDefault();

    this.el.classList.remove("drag-active");
    this.removeDropIndicator();
    this.lastDropTarget = null;

    const files = Array.from(event.dataTransfer.files).filter((f) =>
      f.type.startsWith("image/"),
    );

    if (files.length === 0) return;

    // Use LiveView's upload mechanism via the hidden input
    // Find input by name since live_file_input generates dynamic IDs
    const form = document.getElementById("drop-upload-form");
    const uploadInput = form?.querySelector('input[name="drop_image"]');

    if (uploadInput) {
      const dt = new DataTransfer();
      dt.items.add(files[0]); // Only take first image
      uploadInput.files = dt.files;
      // Dispatch change event - auto_upload: true handles the rest
      uploadInput.dispatchEvent(new Event("change", { bubbles: true }));
    }
  },

  updateDropIndicator(blockEl) {
    this.removeDropIndicator();

    const indicator = document.createElement("div");
    indicator.className = "drop-indicator";
    indicator.id = "drop-indicator";

    if (blockEl) {
      blockEl.after(indicator);
    } else {
      this.el.prepend(indicator);
    }
  },

  removeDropIndicator() {
    document.getElementById("drop-indicator")?.remove();
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
