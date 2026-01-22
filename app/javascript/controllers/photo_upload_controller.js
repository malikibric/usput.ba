import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "previewImage", "filename", "placeholder", "area"]

  select(event) {
    const input = event.target
    if (input.files && input.files[0]) {
      const file = input.files[0]
      this.previewImageTarget.src = URL.createObjectURL(file)
      this.filenameTarget.textContent = file.name
      this.previewTarget.classList.remove("hidden")
      this.placeholderTarget.classList.add("hidden")
      this.areaTarget.classList.remove("border-dashed", "border-gray-300")
      this.areaTarget.classList.add("border-solid", "border-emerald-500")
    }
  }

  clear() {
    this.inputTarget.value = ""
    this.previewTarget.classList.add("hidden")
    this.placeholderTarget.classList.remove("hidden")
    this.areaTarget.classList.add("border-dashed", "border-gray-300")
    this.areaTarget.classList.remove("border-solid", "border-emerald-500")
  }
}
