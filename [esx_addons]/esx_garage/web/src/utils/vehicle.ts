/**
 * Generates the image path for a vehicle based on its model name.
 * Uses relative paths for FiveM NUI compatibility.
 *
 * @param model - The vehicle model name (e.g., "adder", "sultan")
 * @returns Relative path to the vehicle image
 *
 * @example
 * ```typescript
 * getVehicleImagePath("adder") // Returns: "./vehicleImages/adder.webp"
 * getVehicleImagePath("") // Returns: "./vehicleImages/fallback.webp"
 * ```
 */
export const getVehicleImagePath = (model: string): string => {
  if (!model) {
    return './vehicleImages/fallback.webp';
  }

  // Normalize model name: lowercase and trim whitespace
  const normalizedModel = model.toLowerCase().trim();

  return `./vehicleImages/${normalizedModel}.webp`;
};
