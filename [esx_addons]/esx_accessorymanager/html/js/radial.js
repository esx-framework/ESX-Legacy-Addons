'use strict';
(() => {
    const ui = window.AccessoryUI;
    const wheel = document.getElementById('wheel');
    const step = 360 / ui.catalog.length;

    const point = (angle, radius = 50) => {
        const radians = angle * Math.PI / 180;
        return [50 + Math.cos(radians) * radius, 50 + Math.sin(radians) * radius];
    };
    
    ui.catalog.forEach((item, index) => {
        const center = -90 + index * step;
        const start = center - step / 2;
        const polygon = ['50% 50%'];

        for (let part = 0; part <= 24; part++) {
            const [x, y] = point(start + step * part / 24, 50.2);
            polygon.push(`${x}% ${y}%`);
        }

        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'sector';
        button.dataset.action = item.id;
        button.style.clipPath = `polygon(${polygon.join(',')})`;
        button.setAttribute('aria-pressed', 'false');

        const [x, y] = point(center, 36.46);
        const icon = document.createElement('img');
        icon.alt = '';
        icon.className = 'icon';
        icon.setAttribute('aria-hidden', 'true');
        icon.dataset.icon = item.icon;
        icon.style.setProperty('--x', `${x}%`);
        icon.style.setProperty('--y', `${y}%`);
        button.append(icon);
        wheel.append(button);

        const divider = document.createElement('span');
        divider.className = 'divider';
        divider.style.transform = `rotate(${start + 90}deg)`;
        divider.setAttribute('aria-hidden', 'true');
        wheel.append(divider);
    });

    document.querySelectorAll('[data-icon]').forEach(icon => {
        const url = new URL(`assets/icons/${icon.dataset.icon}.png`, document.baseURI);
        icon.src = url.href;
    });
})();
