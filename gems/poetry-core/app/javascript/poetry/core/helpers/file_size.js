// A byte count as a selection list shows it.

const UNITS = ["B", "KB", "MB", "GB"]

/**
 * Formats a byte count for people ("2.0 KB"): whole bytes below a
 * kilobyte, one decimal above.
 *
 * @param {number} bytes
 * @returns {string} empty for a count that is not a size
 */
export function formatFileSize(bytes) {
  if (!Number.isFinite(bytes) || bytes < 0) return ""

  let value = bytes
  let unit = 0

  while (value >= 1024 && unit < UNITS.length - 1) {
    value /= 1024
    unit += 1
  }

  return `${unit === 0 ? value : value.toFixed(1)} ${UNITS[unit]}`
}
