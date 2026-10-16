/**
 * Colors of the numbered bundle markers, shared by the scene and the wiring plan card so a
 * number looks the same in both places.
 */

/** Fill and text color of one marker. */
export interface MarkerStyle {
  /** Disc fill */
  fill: string;
  /** Number color */
  text: string;
}

const STYLES: readonly MarkerStyle[] = [
  { fill: '#fb9b04', text: '#161616' },
  { fill: '#4aa3ff', text: '#0b1a2b' },
  { fill: '#f2f2f2', text: '#161616' },
  { fill: '#46c35a', text: '#0c240f' },
];

/**
 * @param number - Bundle number, starting at 1
 * @returns Marker colors for that number
 */
export function markerStyle(number: number): MarkerStyle {
  return STYLES[(number - 1) % STYLES.length] as MarkerStyle;
}
