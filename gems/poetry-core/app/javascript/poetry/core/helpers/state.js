// The Tier-0 controllable-state convention (the DOM is the store): runtime
// state is a data-state attribute - written here, styled by CSS variants
// (data-[state=open]:...), owned by whichever layer sets it (a Stimulus
// Value default, the DOM, the URL, or a server re-render).

export function stateOf(element) {
  return element.dataset.state
}

export function setState(element, value) {
  element.dataset.state = value
  element.dispatchEvent(
    new CustomEvent("poetry:state-change", { detail: { state: value }, bubbles: true })
  )
  return value
}
