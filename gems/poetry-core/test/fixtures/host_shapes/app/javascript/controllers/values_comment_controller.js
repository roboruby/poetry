import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static values = {
    tone: String, // one of: loud, quiet
    limit: { type: Number, default: 3 },
    /* url: the endpoint, e.g. /a, /b */
    url: String
  }
  pulse() {}
}
