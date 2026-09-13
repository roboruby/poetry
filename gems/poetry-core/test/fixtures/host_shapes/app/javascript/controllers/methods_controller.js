import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["a"]
  connect() {}
  disconnect() {}
  initialize() {}
  render() {}
  targets() {}
  constructor() { super() }
  pulse() {}
  async fetchIt() {}
  arrow = () => {}
  arrowWithArgs = (event) => { this.pulse() }
  #privateMethod() {}
  get foo() { return 1 }
  set foo(v) {}
  static helper() {}
  delete() {}
  withDefault(x = f()) {}
  withDestructure({ target }) {}
  allman()
  {
  }
  multiParam(
    a,
    b
  ) {}
  onDone() {
    this.dispatch("changed")
    this.dispatch(`${this.name}`)
    this.dispatch("a", { prefix: "b" })
    // this.dispatch("commented")
    const s = "this.dispatch(\"stringy\")"
  }
  nested() {
    const o = {
      inner() { return 1 },
    }
    [1].forEach((x) => {
      callback() {
      }
    })
    return o
  }
  afterNested() {}
}
