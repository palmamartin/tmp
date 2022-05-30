import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["name"]

    greet() {
        console.log("you clicked ", this.name)
    }

    get name() {
        return this.nameTarget.value
    }

    connect() {
        console.log("hello", this.element)
    }
}