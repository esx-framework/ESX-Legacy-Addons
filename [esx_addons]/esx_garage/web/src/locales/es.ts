import type { LocaleTranslations } from '@/types/locale.types';

export const es: LocaleTranslations = {
    garage: {
        title: 'Garaje',
        subtitle: 'Gestión de vehículos',
        search: 'Buscar por matrícula, modelo o nombre...',
        noVehicles: 'No se encontraron vehículos',
        loading: 'Cargando vehículos...'
    },
    vehicle: {
        stored: 'Guardado',
        out: 'Fuera',
        impounded: 'En depósito',
        retrieve: 'Retirar',
        store: 'Guardar',
        payImpound: 'Pagar depósito',
        favorite: 'Favorito',
        rename: 'Renombrar',
        details: 'Detalles',
        mileage: 'Kilometraje',
        fuel: 'Combustible',
        engine: 'Motor',
        body: 'Carrocería',
        plate: 'Matrícula',
        customName: 'Nombre personalizado'
    },
    filters: {
        all: 'Todos',
        car: 'Coche',
        motorcycle: 'Motocicleta',
        boat: 'Barco',
        aircraft: 'Aeronave',
        bicycle: 'Bicicleta',
        truck: 'Camión',
        emergency: 'Emergencia',
        showStored: 'Guardados',
        showOut: 'Fuera',
        showImpounded: 'En depósito',
        showFavorites: 'Favoritos'
    },
    stats: {
        total: 'Total',
        stored: 'Guardados',
        out: 'Fuera',
        impounded: 'En depósito'
    },
    actions: {
        close: 'Cerrar',
        confirm: 'Confirmar',
        cancel: 'Cancelar',
        save: 'Guardar',
        delete: 'Eliminar',
        reset: 'Restablecer'
    },
    notifications: {
        vehicleRetrieved: 'Vehículo retirado correctamente',
        vehicleStored: 'Vehículo guardado correctamente',
        vehicleRenamed: 'Vehículo renombrado correctamente',
        impoundPaid: 'Depósito pagado correctamente',
        favoriteAdded: 'Añadido a favoritos',
        favoriteRemoved: 'Eliminado de favoritos',
        error: 'Ha ocurrido un error',
        noSpawnPoints: 'No hay puntos de aparición disponibles',
        notEnoughMoney: 'No tienes suficiente dinero'
    }
};
