// A flow island for the Islands page, with the form seam: a count the
// island owns, written to the hidden input on every change so a submit
// carries it. A morph refresh hands the island the server's value through
// update; the mirror beside the buttons shows what the input holds.

/**
 * Mounts the counter.
 * @param {HTMLElement} element the root that takes the shell's place
 * @param {Object} props the island's props: `count`, `input` (the hidden input) and `focus`
 * @returns {{ unmount: Function, update: Function }} the island's handle
 */
export function mount(element, props) {
  let count = Number(props.input?.value ?? props.count ?? 0)
  element.innerHTML = `
    <div class="flex flex-wrap items-center gap-3">
      <button type="button" class="rounded-md border px-3 py-1 text-sm" data-step="-1" aria-label="Less">&minus;</button>
      <output class="min-w-8 text-center font-mono text-sm"></output>
      <button type="button" class="rounded-md border px-3 py-1 text-sm" data-step="1" aria-label="More">+</button>
      <span class="text-xs text-muted-foreground">the hidden input holds <code data-mirror></code></span>
    </div>`
  const output = element.querySelector("output")
  const mirror = element.querySelector("[data-mirror]")

  const render = () => {
    output.textContent = String(count)
    if (props.input) props.input.value = String(count)
    mirror.textContent = props.input ? props.input.value : "nothing"
  }
  const click = (event) => {
    const step = event.target.closest("[data-step]")?.dataset.step
    if (!step) return
    count += Number(step)
    render()
  }
  element.addEventListener("click", click)
  render()
  if (props.focus) element.querySelector("button").focus()

  return {
    unmount: () => {
      element.removeEventListener("click", click)
      element.innerHTML = ""
    },
    update: (changed) => {
      props = { ...props, ...changed }
      count = Number(changed.count ?? count)
      render()
    }
  }
}
