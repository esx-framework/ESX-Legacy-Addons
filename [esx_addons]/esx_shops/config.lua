Config = {}

Config.Locale = GetConvar('esx:locale', 'fr')

Config.ItemMaxQuantity = 100

Config.Categories = {
    { id = 'drinks',     label = 'Drinks' },
    { id = 'food',       label = 'Food' },
    { id = 'essentials', label = 'Essentials' },
    { id = 'others',     label = 'Others' }
}

Config.Items = {
    { name = 'water',    label = 'Water',    price = 200,  category = 'drinks',     amount = 1, image = 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/water.png' },
    { name = 'sandwich', label = 'Sandwich', price = 500,  category = 'drinks',     amount = 1, image = 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/sprunk.png' },
    { name = 'donut',    label = 'Donut',    price = 50,   category = 'food',       amount = 1, image = 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/donut.png' },
    { name = 'pizza',    label = 'Pizza',    price = 9900, category = 'food',       amount = 1, image = 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/pizza_ham_slice.png' },
    { name = 'lockpick', label = 'Lockpick', price = 2500, category = 'essentials', amount = 1, image = 'https://r2.fivemanage.com/R92pivz8ZlXwjJjTvi3Oq/lockpick.png' }
}

-- Shop locations. Add as many as you want.
-- Each entry: { coords = vector3(x, y, z), marker = true/false, text = 'Display name' }
Config.Locations = {
    { coords = vector3(25.740662, -1347.652710, 29.482056), marker = true, text = 'Shop' },
    { coords = vector3(25.767035, -1345.173584, 29.482056), marker = true, text = 'Shop' },
    -- you can add more locations as you want
}
