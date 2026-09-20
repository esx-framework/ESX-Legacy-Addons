-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

WorkshopLocale = {}

function WorkshopLocale.GetNuiPayload()
    return {
        language = Config.Locale or 'en',
        camera = TranslateCap('camera'),
        close = TranslateCap('close'),
        view = TranslateCap('camera_default'),
        front = TranslateCap('camera_front'),
        back = TranslateCap('camera_back'),
        left = TranslateCap('camera_left'),
        right = TranslateCap('camera_right'),
        top = TranslateCap('camera_top'),
        free = TranslateCap('camera_free'),
        rotateLeft = TranslateCap('camera_rotate_left'),
        rotateRight = TranslateCap('camera_rotate_right'),
        zoomIn = TranslateCap('camera_zoom_in'),
        zoomOut = TranslateCap('camera_zoom_out'),
        stats = TranslateCap('vehicle_stats'),
        speed = TranslateCap('stats_speed'),
        accel = TranslateCap('stats_accel'),
        brake = TranslateCap('stats_brake'),
        handling = TranslateCap('stats_handling'),
        backButton = TranslateCap('back'),
        add = TranslateCap('add'),
        pay = TranslateCap('pay'),
        cart = TranslateCap('cart'),
        clear = TranslateCap('cart_clear_short'),
        total = TranslateCap('cart_total'),
        installed = TranslateCap('installed'),
        noOptions = TranslateCap('no_options'),
        emptyCart = TranslateCap('cart_empty'),
        mod = TranslateCap('mod_label'),
        customize = TranslateCap('ui_customize'),
        search = TranslateCap('ui_search'),
        noResults = TranslateCap('ui_no_results'),
        selection = TranslateCap('ui_selection'),
        inCart = TranslateCap('ui_in_cart'),
        addToCart = TranslateCap('ui_add_to_cart'),
        list = TranslateCap('ui_list'),
        grid = TranslateCap('ui_grid'),
        requestFailed = TranslateCap('ui_request_failed'),
        freeCameraHelp = TranslateCap('free_camera_help')
    }
end
