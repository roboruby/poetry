// The nullable-segment date/time value (the IncompleteDate model, adapted
// from react-aria - Apache-2.0, see THIRD_PARTY_NOTICES.md): segments
// are stored RAW so a user can edit day before
// month - the object can hold February 31st and only commit constrains.
// Hour is stored in the LOCALE'S HOUR CYCLE with a separate dayPeriod bit
// (0 = AM, 1 = PM), so am/pm edits are independent and "12 means 0" lives
// in exactly one place. Gregorian-only by design (the calendar seam is
// clean if that ever changes - limits() is the only calendar knowledge).

const DAYS_IN_MONTH = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

/** PageUp/PageDown step per segment type. */
export const PAGE_STEP = { year: 5, month: 2, day: 7, hour: 2, minute: 15, second: 15 }

/**
 * Days in a Gregorian month, leap Februaries included.
 *
 * @param {number} year
 * @param {number} month - 1-12 (out-of-range months report 31)
 * @returns {number}
 */
export function daysInMonth(year, month) {
  if (month === 2 && year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0)) return 29

  return DAYS_IN_MONTH[month - 1] ?? 31
}

function pad(number, width = 2) {
  return String(number).padStart(width, "0")
}

/**
 * A date/time value whose segments may each be null (the module header
 * holds the storage rules). One instance backs one date-field.
 */
export class IncompleteDate {
  /**
   * @param {"h11" | "h12" | "h23" | "h24"} [hourCycle="h23"] - the
   *   field's RESOLVED cycle ({@link resolveHourCycle})
   */
  constructor(hourCycle = "h23") {
    this.hourCycle = hourCycle
    this.year = null
    this.month = null
    this.day = null
    this.hour = null // stored in the display cycle, NOT h23
    this.minute = null
    this.second = null
    this.dayPeriod = null // 0 | 1 | null; only meaningful under h11/h12
  }

  /** @returns {boolean} whether the cycle carries a dayPeriod (h11/h12) */
  get twelveHour() {
    return this.hourCycle === "h11" || this.hourCycle === "h12"
  }

  /**
   * Segment limits in DISPLAY terms. Day deliberately allows the calendar
   * maximum (31) regardless of the month segment - editing order must not
   * trap the user; constrain() clamps at commit.
   *
   * @param {string} type - "year" | "month" | "day" | "hour" | "minute" |
   *   "second" | "dayPeriod"
   * @returns {{ min: number, max: number }}
   */
  limits(type) {
    switch (type) {
      case "year": return { min: 1, max: 9999 }
      case "month": return { min: 1, max: 12 }
      case "day": return { min: 1, max: 31 }
      case "minute":
      case "second": return { min: 0, max: 59 }
      case "dayPeriod": return { min: 0, max: 1 }
      case "hour":
        switch (this.hourCycle) {
          case "h11": return { min: 0, max: 11 }
          case "h12": return { min: 1, max: 12 }
          case "h24": return { min: 1, max: 24 }
          default: return { min: 0, max: 23 }
        }
      default: return { min: 0, max: 0 }
    }
  }

  /**
   * Arrow/page steps a segment. The first press on an EMPTY segment lands
   * on the placeholder value, the second one moves it (the cycle
   * contract); values wrap within the segment's limits (the spinbutton
   * contract).
   *
   * @param {string} type - the segment
   * @param {number} amount - signed step
   * @param {number} placeholderValue - what an empty segment lands on
   * @param {Object} [options]
   * @param {boolean} [options.round=false] - PageUp/Down snap to the next
   *   multiple of amount instead of adding it
   */
  cycle(type, amount, placeholderValue, { round = false } = {}) {
    const { min, max } = this.limits(type)
    const current = this[type]

    if (current === null) {
      this[type] = clampToLimits(placeholderValue, min, max)
      return
    }

    if (type === "dayPeriod") {
      this.dayPeriod = current === 0 ? 1 : 0
      return
    }

    let next

    if (round) {
      const step = Math.abs(amount)

      next = amount > 0
        ? Math.floor(current / step) * step + step
        : Math.ceil(current / step) * step - step
    } else {
      next = current + amount
    }

    // Wrap (the spinbutton contract), keeping the span inclusive.
    const span = max - min + 1
    next = ((next - min) % span + span) % span + min

    this[type] = next
  }

  /**
   * Sets a segment, clamped to its limits.
   *
   * @param {string} type
   * @param {number | null} value - null clears
   */
  set(type, value) {
    const { min, max } = this.limits(type)

    this[type] = value === null ? null : clampToLimits(value, min, max)
  }

  /**
   * Empties a segment.
   * @param {string} type
   */
  clear(type) {
    this[type] = null
  }

  /**
   * Whether every listed segment holds a value.
   *
   * @param {string[]} types
   * @returns {boolean}
   */
  isComplete(types) {
    return types.every((type) => this[type] !== null)
  }

  /**
   * A complete date can still be invalid (February 31st): valid means the
   * day exists in the month.
   *
   * @returns {boolean} false while year/month/day are incomplete
   */
  isValidDate() {
    if (this.year === null || this.month === null || this.day === null) return false

    return this.day <= daysInMonth(this.year, this.month)
  }

  /**
   * Commit-time clamp (blur): the raw day is pulled into the real month.
   *
   * @param {string[]} types - the field's segments; day is only clamped
   *   when listed
   */
  constrain(types) {
    if (types.includes("day") && this.year !== null && this.month !== null && this.day !== null) {
      this.day = Math.min(this.day, daysInMonth(this.year, this.month))
    }
  }

  // --- hour-cycle conversion (the ONE place "12 means 0" lives) ---

  /**
   * The stored hour converted to h23. Under h11/h12 an unset dayPeriod
   * reads as AM.
   *
   * @returns {number | null} null while the hour is unset
   */
  hourInH23() {
    if (this.hour === null) return null

    switch (this.hourCycle) {
      case "h11":
        return this.hour + (this.dayPeriod === 1 ? 12 : 0)
      case "h12": {
        const base = this.hour % 12
        return base + (this.dayPeriod === 1 ? 12 : 0)
      }
      case "h24":
        return this.hour % 24
      default:
        return this.hour
    }
  }

  /**
   * Sets hour (and dayPeriod under h11/h12) from an h23 hour.
   * @param {number} h23 - 0-23
   */
  setFromH23(h23) {
    switch (this.hourCycle) {
      case "h11":
        this.hour = h23 % 12
        this.dayPeriod = h23 < 12 ? 0 : 1
        break
      case "h12":
        this.hour = h23 % 12 === 0 ? 12 : h23 % 12
        this.dayPeriod = h23 < 12 ? 0 : 1
        break
      case "h24":
        this.hour = h23 === 0 ? 24 : h23
        break
      default:
        this.hour = h23
    }
  }

  // --- ISO serialization (the native input's value format) ---

  /** @returns {string | null} "YYYY-MM-DD", or null while incomplete */
  toISODate() {
    if (!this.isComplete(["year", "month", "day"])) return null

    return `${pad(this.year, 4)}-${pad(this.month)}-${pad(this.day)}`
  }

  /**
   * @param {boolean} [withSeconds=false]
   * @returns {string | null} "HH:MM" or "HH:MM:SS" (h23 on the wire), or
   *   null while incomplete (a twelve-hour cycle needs dayPeriod too)
   */
  toISOTime(withSeconds = false) {
    const types = withSeconds ? ["hour", "minute", "second"] : ["hour", "minute"]

    if (this.twelveHour && this.dayPeriod === null) return null
    if (!this.isComplete(types)) return null

    const h23 = this.hourInH23()
    const base = `${pad(h23)}:${pad(this.minute)}`

    return withSeconds ? `${base}:${pad(this.second)}` : base
  }

  /**
   * Fills year/month/day from "YYYY-MM-DD".
   *
   * @param {string | null} iso
   * @returns {boolean} false (nothing touched) on a non-matching string
   */
  setFromISODate(iso) {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso ?? "")

    if (!match) return false

    this.year = Number(match[1])
    this.month = Number(match[2])
    this.day = Number(match[3])
    return true
  }

  /**
   * Fills hour/minute(/second) from "HH:MM(:SS)" (h23 on the wire).
   *
   * @param {string | null} iso
   * @returns {boolean} false (nothing touched) on a non-matching string
   */
  setFromISOTime(iso) {
    const match = /^(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(iso ?? "")

    if (!match) return false

    this.setFromH23(Number(match[1]))
    this.minute = Number(match[2])
    this.second = match[3] === undefined ? null : Number(match[3])
    return true
  }
}

function clampToLimits(value, min, max) {
  return Math.min(max, Math.max(min, value))
}

/**
 * The resolved hour cycle for a locale, with two known Intl bug
 * detections built in: Chrome resolves `hour12: false` to the buggy h24
 * per the ECMA-402 spec bug, and WebKit misreports
 * resolvedOptions().hourCycle in some locales - so the cycle is INFERRED
 * by formatting hour 0 and hour 23 and reading what comes out.
 *
 * @param {string | undefined} locale
 * @param {"h11" | "h12" | "h23" | "h24" | null} [override=null] - wins
 *   outright when present
 * @returns {"h11" | "h12" | "h23" | "h24"}
 */
export function resolveHourCycle(locale, override = null) {
  if (override) return override

  const formatter = new Intl.DateTimeFormat(locale, { hour: "numeric" })
  const hourAt = (hour) => {
    const parts = formatter.formatToParts(new Date(2020, 0, 1, hour))

    return {
      value: Number(parts.find((part) => part.type === "hour")?.value ?? NaN),
      dayPeriod: parts.some((part) => part.type === "dayPeriod")
    }
  }
  const midnight = hourAt(0)
  const evening = hourAt(23)

  if (midnight.dayPeriod || evening.dayPeriod) return midnight.value === 0 ? "h11" : "h12"

  return midnight.value === 0 || evening.value === 23 ? "h23" : "h24"
}
