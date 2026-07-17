export interface Vehicle {
  owner?: string;               // Veh Owner
  plate: string;                // Vehicle plate
  model?: number;               // GTA model hash
  type: string;                 // Vehicle type (for ex. sports, suv etc...)
  name: string;                 // Vehicle Name
  mileage?: number | null;      // Vehicle Mileage
  impounded: boolean;           // Whether the vehicle is impounded or not
  impoundName?: string | null;   // Current impound identifier
  stored?: boolean;             // Whether the vehicle is stored in a garage
}
