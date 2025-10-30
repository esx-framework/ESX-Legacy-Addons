<script lang="ts">
import { ghostManager } from '../stores/GhostManager.svelte';
import { fetchNui } from '../utils/fetchNui';

let { visible = $bindable(false), forced = $bindable(false) } = $props();

let countdown = $state(15);
let intervalId: number | null = null;

// Manage countdown interval lifecycle - cleanup properly on all state changes
$effect(() => {
    // Cleanup any existing interval first
    if (intervalId) {
        clearInterval(intervalId);
        intervalId = null;
    }

    // Only start countdown if visible and not forced
    if (visible && !forced) {
        countdown = 15;
        intervalId = window.setInterval(() => {
            countdown--;
            if (countdown <= 0) {
                if (intervalId) {
                    clearInterval(intervalId);
                    intervalId = null;
                }
                handleChoice('normal');
            }
        }, 1000);
    }

    // Cleanup on unmount or when dependencies change
    return () => {
        if (intervalId) {
            clearInterval(intervalId);
            intervalId = null;
        }
    };
});

function handleChoice(choice: 'ghost' | 'normal') {
    // Clean up interval before closing
    if (intervalId) {
        clearInterval(intervalId);
        intervalId = null;
    }

    fetchNui('ghostChoice', { choice });
    visible = false;
}
</script>

{#if visible}
<div class="ghost-choice-overlay">
    <div class="ghost-choice-modal">
        <div class="pumpkin-decoration">
            <img src="./assets/pumpkin.webp" alt="pumpkin" />
        </div>

        <h2>Spooky Opportunity!</h2>
        <p>You have a chance to respawn as a ghost and haunt the living...</p>

        <div class="buttons">
            <button class="btn btn-ghost" onclick={() => handleChoice('ghost')}>
                Become a Ghost
            </button>
            <button class="btn btn-normal" onclick={() => handleChoice('normal')}>
                Respawn Normally
            </button>
        </div>

        {#if !forced}
        <div class="countdown">Auto-decline in {countdown}s</div>
        {/if}
    </div>
</div>
{/if}

<style>
.ghost-choice-overlay {
    position: fixed;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0, 0, 0, 0.8);
    z-index: 1000;
    animation: fadeIn 0.3s ease;
}

.ghost-choice-modal {
    background: rgba(26, 26, 26, 0.95);
    border: 2px solid var(--primary-color, #fb9b04);
    border-radius: 8px;
    padding: 2rem;
    min-width: 400px;
    text-align: center;
    position: relative;
    animation: slideUp 0.4s ease;
}

.pumpkin-decoration {
    position: absolute;
    top: -40px;
    left: 50%;
    transform: translateX(-50%);
    width: 80px;
    height: 80px;
}

.pumpkin-decoration img {
    width: 100%;
    height: 100%;
    filter: drop-shadow(0 0 20px var(--primary-color, #fb9b04));
    animation: glow 2s ease-in-out infinite;
}

h2 {
    color: var(--primary-color, #fb9b04);
    font-size: 2rem;
    margin: 1rem 0;
    font-family: 'Creepster', cursive;
}

p {
    color: rgba(255, 255, 255, 0.9);
    margin-bottom: 2rem;
}

.buttons {
    display: flex;
    gap: 1rem;
    justify-content: center;
}

.btn {
    padding: 0.75rem 1.5rem;
    border: none;
    border-radius: 4px;
    font-size: 1rem;
    cursor: pointer;
    transition: all 0.2s ease;
    font-weight: 600;
}

.btn-ghost {
    background: var(--primary-color, #fb9b04);
    color: #000;
}

.btn-ghost:hover {
    transform: scale(1.05);
    box-shadow: 0 0 20px var(--primary-color, #fb9b04);
}

.btn-normal {
    background: rgba(255, 255, 255, 0.1);
    color: #fff;
    border: 1px solid rgba(255, 255, 255, 0.2);
}

.btn-normal:hover {
    background: rgba(255, 255, 255, 0.2);
}

.countdown {
    margin-top: 1rem;
    color: rgba(255, 255, 255, 0.5);
    font-size: 0.875rem;
}

@keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
}

@keyframes slideUp {
    from {
        opacity: 0;
        transform: translateY(20px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

@keyframes glow {
    0%, 100% {
        filter: drop-shadow(0 0 20px var(--primary-color, #fb9b04));
    }
    50% {
        filter: drop-shadow(0 0 30px var(--primary-color, #fb9b04));
    }
}
</style>
