/**
 * AutoFocus Hook
 * Automatically focuses the element when mounted.
 */
const AutoFocus = {
  mounted() {
    this.el.focus();
  },
};

export default AutoFocus;
