import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    param: { type: String, default: "q" },
    frameId: String,
    debounceMs: { type: Number, default: 200 }
  }

  type(event) {
    const field = event.target
    if (!field || field.name !== this.paramValue) return

    window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.request(field.value || ""), this.debounceMsValue)
  }

  disconnect() {
    window.clearTimeout(this.timer)
  }

  request(value) {
    const frame = document.getElementById(this.frameIdValue)
    if (!frame) return

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set(this.paramValue, value)
    frame.setAttribute("src", url.toString())
  }
}
