/**
 * Sound Manager
 * Centralized audio management for Halloween event sounds
 * Handles loading, playing, and stopping audio files with volume control
 */

/**
 * Sound configuration interface
 */
interface SoundConfig {
  element: HTMLAudioElement;
  volume: number;
  duration: number;
}

/**
 * Sound Manager Class
 * Manages audio playback for UI events
 */
class SoundManager {
  private sounds: Map<string, SoundConfig> = new Map();
  private masterVolume: number = 1.0;

  /**
   * Load an audio file and cache it
   * Preloading ensures sounds play immediately when requested
   *
   * @param name - Unique identifier for the sound
   * @param path - Path to audio file relative to public folder
   * @param volume - Volume level (0.0 to 1.0), default 1.0
   */
  load(name: string, path: string, volume: number = 1.0): void {
    try {
      if (this.sounds.has(name)) {
        console.warn(`[SoundManager] Sound "${name}" already loaded, skipping`);
        return;
      }

      const audio = new Audio();
      audio.src = path;
      audio.preload = 'auto';
      audio.volume = Math.min(1.0, Math.max(0.0, volume * this.masterVolume));

      // Store duration once loaded
      audio.addEventListener('loadedmetadata', () => {
        const config = this.sounds.get(name);
        if (config) {
          config.duration = audio.duration * 1000; // Convert to ms
        }
      });

      audio.addEventListener('error', () => {
        console.error(`[SoundManager] Failed to load sound: ${name} from ${path}`);
      });

      this.sounds.set(name, {
        element: audio,
        volume: volume,
        duration: 0,
      });
    } catch (error) {
      console.error(`[SoundManager] Error loading sound "${name}":`, error);
    }
  }

  /**
   * Play a loaded sound
   * Restarts playback if already playing
   *
   * @param name - Sound identifier to play
   */
  play(name: string): void {
    const config = this.sounds.get(name);

    if (!config) {
      console.warn(`[SoundManager] Sound not loaded: ${name}`);
      return;
    }

    try {
      // Reset to beginning if already playing
      config.element.currentTime = 0;
      config.element.play().catch((error) => {
        console.warn(`[SoundManager] Failed to play "${name}":`, error);
      });
    } catch (error) {
      console.error(`[SoundManager] Error playing sound "${name}":`, error);
    }
  }

  /**
   * Stop playback and reset position
   *
   * @param name - Sound identifier to stop
   */
  stop(name: string): void {
    const config = this.sounds.get(name);

    if (!config) {
      console.warn(`[SoundManager] Sound not loaded: ${name}`);
      return;
    }

    try {
      config.element.pause();
      config.element.currentTime = 0;
    } catch (error) {
      console.error(`[SoundManager] Error stopping sound "${name}":`, error);
    }
  }

  /**
   * Stop all currently playing sounds
   */
  stopAll(): void {
    this.sounds.forEach((config) => {
      try {
        config.element.pause();
        config.element.currentTime = 0;
      } catch (error) {
        console.error('[SoundManager] Error stopping all sounds:', error);
      }
    });
  }

  /**
   * Set volume for a specific sound
   * Volume is multiplied by master volume
   *
   * @param name - Sound identifier
   * @param volume - Volume level (0.0 to 1.0)
   */
  setVolume(name: string, volume: number): void {
    const config = this.sounds.get(name);

    if (!config) {
      console.warn(`[SoundManager] Sound not loaded: ${name}`);
      return;
    }

    const clampedVolume = Math.min(1.0, Math.max(0.0, volume));
    config.volume = clampedVolume;
    config.element.volume = clampedVolume * this.masterVolume;
  }

  /**
   * Set master volume (affects all sounds)
   * Individual sound volumes are multiplied by this value
   *
   * @param volume - Master volume level (0.0 to 1.0)
   */
  setMasterVolume(volume: number): void {
    this.masterVolume = Math.min(1.0, Math.max(0.0, volume));

    // Apply to all loaded sounds
    this.sounds.forEach((config) => {
      config.element.volume = config.volume * this.masterVolume;
    });
  }

  /**
   * Get master volume level
   *
   * @returns Current master volume (0.0 to 1.0)
   */
  getMasterVolume(): number {
    return this.masterVolume;
  }

  /**
   * Check if a sound is currently playing
   *
   * @param name - Sound identifier
   * @returns True if sound is playing, false otherwise
   */
  isPlaying(name: string): boolean {
    const config = this.sounds.get(name);

    if (!config) {
      return false;
    }

    return !config.element.paused && !config.element.ended;
  }

  /**
   * Get duration of a loaded sound
   *
   * @param name - Sound identifier
   * @returns Duration in milliseconds, or 0 if not loaded
   */
  getDuration(name: string): number {
    const config = this.sounds.get(name);
    return config?.duration || 0;
  }

  /**
   * Get current playback position
   *
   * @param name - Sound identifier
   * @returns Current time in milliseconds, or 0 if not loaded
   */
  getCurrentTime(name: string): number {
    const config = this.sounds.get(name);
    return config ? config.element.currentTime * 1000 : 0;
  }

  /**
   * Set playback position
   *
   * @param name - Sound identifier
   * @param time - Time in milliseconds
   */
  setCurrentTime(name: string, time: number): void {
    const config = this.sounds.get(name);

    if (!config) {
      console.warn(`[SoundManager] Sound not loaded: ${name}`);
      return;
    }

    config.element.currentTime = time / 1000;
  }

  /**
   * Remove a sound from cache (cleanup)
   *
   * @param name - Sound identifier
   */
  unload(name: string): void {
    const config = this.sounds.get(name);

    if (!config) {
      return;
    }

    try {
      config.element.pause();
      config.element.src = '';
    } catch (error) {
      console.error(`[SoundManager] Error unloading sound "${name}":`, error);
    }

    this.sounds.delete(name);
  }

  /**
   * Unload all sounds (cleanup on resource stop)
   */
  unloadAll(): void {
    this.sounds.forEach((config) => {
      try {
        config.element.pause();
        config.element.src = '';
      } catch (error) {
        console.error('[SoundManager] Error unloading sounds:', error);
      }
    });

    this.sounds.clear();
  }

  /**
   * Get list of all loaded sound names
   *
   * @returns Array of sound identifiers
   */
  getLoadedSounds(): string[] {
    return Array.from(this.sounds.keys());
  }
}

/**
 * Singleton instance
 * Use throughout the application via:
 * import { soundManager } from './utils/soundManager'
 */
export const soundManager = new SoundManager();

/**
 * Sound Library Initialization
 * Call this once on app startup to preload all sounds
 */
export function initializeSounds(): void {
  try {
    // Trick-or-Treat sounds
    soundManager.load('trick-success', './assets/trick-success.mp3', 0.8);
    soundManager.load('trick-trick', './assets/trick-trick.mp3', 0.7);
  } catch (error) {
    console.error('[SoundManager] Error during initialization:', error);
  }
}

export default soundManager;
