/* @refresh reload */
import { render } from 'solid-js/web';
import { Router } from "@solidjs/router";

import './index.css';
import App from './App';
import {HudStorageProvider, SettingsStorageProvider} from './assets/Contexts/index'

render(
    () => (
        <Router>
            <SettingsStorageProvider>
                <HudStorageProvider>
                    <App />
                </HudStorageProvider>
            </SettingsStorageProvider>
        </Router>
    ),
    document.getElementById("root")
);
