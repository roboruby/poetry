// Type shim for the verbatim recharts copies in this vendor tree: the
// original `src/util/scale/getNiceTickValues.ts` imports NumberDomain from
// `../types`; this file provides ONLY that type (from recharts
// src/util/types.ts v3.9.2) so the copies bundle without modification.
export type NumberDomain = readonly [min: number, max: number];
