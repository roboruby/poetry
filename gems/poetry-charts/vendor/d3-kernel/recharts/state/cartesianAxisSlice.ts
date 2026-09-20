// Type shim for the verbatim recharts copies in this vendor tree: the
// original `src/util/scale/getNiceTickValues.ts` imports
// NiceTicksAlgorithm from `../../state/cartesianAxisSlice`; this file
// provides ONLY that type (from recharts v3.9.2) so the copies bundle
// without modification.
export type NiceTicksAlgorithm = 'none' | 'auto' | 'adaptive' | 'snap125';
