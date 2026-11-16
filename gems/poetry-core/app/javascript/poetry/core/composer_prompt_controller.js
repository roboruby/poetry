import { Controller } from "@hotwired/stimulus"

/**
 * A suggested prompt for a Composer elsewhere on the page: a chip under
 * an empty conversation, a quick reply, a retry. Pressed, it asks the
 * named composer to take its text, and by default to send it, by
 * dispatching poetry:composer:prompt on the window. The composer does
 * the writing and the sending itself, through its own gate, so a prompt
 * can do nothing a typed message could not.
 */
export default class ComposerPromptController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:composer:prompt"]

  static values = {
    // The id of the composer the prompt is for.
    composer: String,
    // The text the prompt writes in place of the draft.
    text: String,
    // Whether the composer sends the text at once. Off, the text is
    // written and the caret put after it, for the person to finish.
    send: { type: Boolean, default: true }
  }

  /** The click action: hands the prompt to the composer it names. */
  write() {
    window.dispatchEvent(new CustomEvent("poetry:composer:prompt", {
      detail: { composer: this.composerValue, text: this.textValue, send: this.sendValue }
    }))
  }
}
