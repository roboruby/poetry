import { describe, expect, it } from "vitest"
import {
  IncompleteDate, daysInMonth, resolveHourCycle
} from "@poetry/controllers/helpers/incomplete_date"

// The nullable-segment value object: raw segments (February 31st
// is representable), hour stored in the locale's cycle with a separate
// dayPeriod bit, ISO round-trips, and the inferred hour cycle (the two
// Intl bugs make resolvedOptions() untrustworthy).

describe("helpers/incomplete_date", () => {
  describe("cycle", () => {
    it("the first arrow on an EMPTY segment fills the placeholder; the second one steps", () => {
      const value = new IncompleteDate()

      value.cycle("month", 1, 7)
      expect(value.month).toBe(7)

      value.cycle("month", 1, 7)
      expect(value.month).toBe(8)
    })

    it("wraps at the limits (spinbutton contract)", () => {
      const value = new IncompleteDate()

      value.month = 12
      value.cycle("month", 1, 1)
      expect(value.month).toBe(1)

      value.cycle("month", -1, 1)
      expect(value.month).toBe(12)
    })

    it("round mode snaps to the next multiple (PageUp on minutes: 7 -> 15, not 22)", () => {
      const value = new IncompleteDate()

      value.minute = 7
      value.cycle("minute", 15, 0, { round: true })
      expect(value.minute).toBe(15)

      value.cycle("minute", -15, 0, { round: true })
      expect(value.minute).toBe(0)
    })

    it("dayPeriod toggles", () => {
      const value = new IncompleteDate("h12")

      value.dayPeriod = 0
      value.cycle("dayPeriod", 1, 0)
      expect(value.dayPeriod).toBe(1)
    })
  })

  describe("hour cycles ('12 means 0' lives in one place)", () => {
    it("h12: noon and midnight round-trip", () => {
      const value = new IncompleteDate("h12")

      value.setFromH23(0)
      expect(value.hour).toBe(12)
      expect(value.dayPeriod).toBe(0)
      expect(value.hourInH23()).toBe(0)

      value.setFromH23(12)
      expect(value.hour).toBe(12)
      expect(value.dayPeriod).toBe(1)
      expect(value.hourInH23()).toBe(12)
    })

    it("h23 passes through; h24 renders midnight as 24", () => {
      const h23 = new IncompleteDate("h23")

      h23.setFromH23(0)
      expect(h23.hour).toBe(0)

      const h24 = new IncompleteDate("h24")

      h24.setFromH23(0)
      expect(h24.hour).toBe(24)
      expect(h24.hourInH23()).toBe(0)
    })

    it("hour limits follow the cycle (h12 1-12, h23 0-23, h11 0-11)", () => {
      expect(new IncompleteDate("h12").limits("hour")).toEqual({ min: 1, max: 12 })
      expect(new IncompleteDate("h23").limits("hour")).toEqual({ min: 0, max: 23 })
      expect(new IncompleteDate("h11").limits("hour")).toEqual({ min: 0, max: 11 })
    })
  })

  describe("validity and constrain (February 31st is representable)", () => {
    it("holds Feb 31 as complete-but-invalid; constrain clamps to the real month end", () => {
      const value = new IncompleteDate()

      value.year = 2020
      value.month = 2
      value.day = 31

      expect(value.isComplete(["year", "month", "day"])).toBe(true)
      expect(value.isValidDate()).toBe(false)

      value.constrain(["year", "month", "day"])
      expect(value.day).toBe(29) // 2020 is a leap year
      expect(value.isValidDate()).toBe(true)
    })

    it("daysInMonth knows the century leap rule", () => {
      expect(daysInMonth(1900, 2)).toBe(28)
      expect(daysInMonth(2000, 2)).toBe(29)
    })
  })

  describe("ISO round-trips (the native input's wire format)", () => {
    it("date: toISODate needs all three fields and pads", () => {
      const value = new IncompleteDate()

      expect(value.toISODate()).toBeNull()

      value.setFromISODate("2026-07-03")
      expect(value.year).toBe(2026)
      expect(value.month).toBe(7)
      expect(value.day).toBe(3)
      expect(value.toISODate()).toBe("2026-07-03")
    })

    it("time: h12 storage still serializes h23 ISO; twelve-hour needs dayPeriod", () => {
      const value = new IncompleteDate("h12")

      value.hour = 1
      value.minute = 5
      expect(value.toISOTime()).toBeNull() // no dayPeriod yet

      value.dayPeriod = 1
      expect(value.toISOTime()).toBe("13:05")

      const parsed = new IncompleteDate("h12")

      parsed.setFromISOTime("13:05")
      expect(parsed.hour).toBe(1)
      expect(parsed.dayPeriod).toBe(1)
      expect(parsed.toISOTime(true)).toBeNull() // seconds requested, none held
    })
  })

describe("ISO datetime round-trips (datetime-local's wire format)", () => {
  it("fills both halves from one string and serializes them back", () => {
    const value = new IncompleteDate("h23")

    expect(value.setFromISODateTime("2026-07-13T13:05")).toBe(true)
    expect(value.toISODateTime()).toBe("2026-07-13T13:05")
    expect(value.toISODateTime(true)).toBe(null) // seconds requested, none set
  })

  it("refuses a string missing either half and leaves the value untouched", () => {
    const value = new IncompleteDate("h23")

    expect(value.setFromISODateTime("2026-07-13")).toBe(false)
    expect(value.setFromISODateTime("13:05")).toBe(false)
    expect(value.toISODateTime()).toBe(null)
  })
})

describe("resolveHourCycle (inferred, never trusted)", () => {
    it("en-US infers a twelve-hour cycle; en-GB a twenty-three-hour one; overrides pin", () => {
      expect(resolveHourCycle("en-US")).toBe("h12")
      expect(resolveHourCycle("en-GB")).toBe("h23")
      expect(resolveHourCycle("en-US", "h23")).toBe("h23")
    })
  })
})
