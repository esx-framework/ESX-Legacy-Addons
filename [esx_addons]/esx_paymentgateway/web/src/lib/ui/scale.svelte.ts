/**
 * Size of the dialog for the player's screen. The ESX UI kit is drawn in pixels for 1080p; the
 * dialog is zoomed by the screen height so it looks the same from 720p up to 4K. Below 1080p the
 * zoom stops shrinking early, so texts stay readable.
 *
 * @see uiScale
 */

/** Screen height the kit's pixel sizes are drawn for. */
const DESIGN_HEIGHT = 1080;
/** Smallest zoom, reached around 860 pixels of height. */
const MIN_ZOOM = 0.8;
/** Largest zoom, reached at 4K. */
const MAX_ZOOM = 2;

/**
 * @param height - Viewport height in CSS pixels
 * @returns Zoom factor for the dialog
 */
export function zoomFor(height: number): number {
  return Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, height / DESIGN_HEIGHT));
}

/** Zoom of the dialog, kept in step with the window. */
class UiScale {
  /** Current zoom factor */
  zoom: number = $state(zoomFor(typeof window === 'undefined' ? DESIGN_HEIGHT : innerHeight));

  /**
   * Follows the window size until the returned function is called.
   *
   * @returns Function that stops following
   */
  track(): () => void {
    const update = (): void => {
      this.zoom = zoomFor(innerHeight);
    };
    update();
    addEventListener('resize', update);
    return (): void => removeEventListener('resize', update);
  }
}

/** Zoom of the dialog. */
export const uiScale = new UiScale();
