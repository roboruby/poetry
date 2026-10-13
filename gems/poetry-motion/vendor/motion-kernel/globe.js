// The @poetry/motion/globe kernel: cobe's createGlobe, loaded only by the
// globe effect. Rebuild with `npm run vendor:motion`.

export { default as createGlobe } from "cobe"

// eslint-disable-next-line no-undef -- injected by build.mjs
export const KERNEL_VERSIONS = __KERNEL_VERSIONS__
