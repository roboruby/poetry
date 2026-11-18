// The @poetry/motion/engine surface: the framework-free motion API the
// motion behaviors use, vendored as one file and fetched only on demand
// (loadEngine in @poetry/motion/load_engine). Nothing from Motion+, the
// paid package.
//
// Not a public motion distribution: an implementation detail behind a
// host-remappable importmap pin. Rebuild with `npm run vendor:motion`; the
// JS suite drift-gates the committed bundle.

export {
  animate, scroll, inView, hover, press, stagger, spring, transform,
  frame, cancelFrame, resize, animateView, MotionGlobalConfig,
} from "motion"

// eslint-disable-next-line no-undef -- injected by build.mjs
export const KERNEL_VERSIONS = __KERNEL_VERSIONS__
