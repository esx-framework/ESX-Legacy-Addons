<script lang="ts">
let { visible = $bindable(false), maxDuration = $bindable(600000), exitKey = $bindable('X'), scareKey = $bindable('E') } = $props();

let timeRemaining = $state(maxDuration);
let intervalId: number | null = null;

$effect(() => {
    if (visible) {
        timeRemaining = maxDuration;
        intervalId = window.setInterval(() => {
            timeRemaining -= 1000;
            if (timeRemaining <= 0) {
                timeRemaining = 0;
                visible = false;
            }
        }, 1000);
    }

    return () => {
        if (intervalId) {
            clearInterval(intervalId);
            intervalId = null;
        }
    };
});

function formatTime(ms: number): string {
    const minutes = Math.floor(ms / 60000);
    const seconds = Math.floor((ms % 60000) / 1000);
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
}
</script>

{#if visible}
<div class="ghost-hud">
    <div class="ghost-status">
        <div class="ghost-icon">👻</div>
        <div class="ghost-info">
            <div class="ghost-label">Ghost Mode</div>
            <div class="ghost-timer">{formatTime(timeRemaining)}</div>
        </div>
    </div>

    <div class="ghost-abilities">
        <div class="ability">
            <div class="ability-key">{scareKey}</div>
            <div class="ability-label">Scare</div>
        </div>
    </div>

    <div class="exit-info">
        Press <span class="key">{exitKey}</span> to exit
    </div>
</div>
{/if}

<style>
.ghost-hud {
    position: fixed;
    bottom: 2rem;
    right: 2rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
    animation: slideIn 0.3s ease;
}

.ghost-status {
    background: rgba(26, 26, 26, 0.9);
    border: 1px solid var(--primary-color, #fb9b04);
    border-radius: 8px;
    padding: 1rem;
    display: flex;
    align-items: center;
    gap: 1rem;
    min-width: 200px;
}

.ghost-icon {
    font-size: 2rem;
    filter: drop-shadow(0 0 10px var(--primary-color, #fb9b04));
}

.ghost-info {
    flex: 1;
}

.ghost-label {
    color: var(--primary-color, #fb9b04);
    font-size: 0.875rem;
    font-weight: 600;
    margin-bottom: 0.25rem;
}

.ghost-timer {
    color: rgba(255, 255, 255, 0.9);
    font-size: 1.25rem;
    font-weight: 700;
    font-family: monospace;
}

.ghost-abilities {
    background: rgba(26, 26, 26, 0.9);
    border: 1px solid rgba(251, 155, 4, 0.3);
    border-radius: 8px;
    padding: 0.75rem;
}

.ability {
    display: flex;
    align-items: center;
    gap: 0.75rem;
}

.ability-key {
    background: var(--primary-color, #fb9b04);
    color: #000;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    font-weight: 700;
    font-size: 0.875rem;
}

.ability-label {
    color: rgba(255, 255, 255, 0.8);
    font-size: 0.875rem;
}

.exit-info {
    background: rgba(255, 59, 59, 0.1);
    border: 1px solid rgba(255, 59, 59, 0.3);
    border-radius: 4px;
    padding: 0.75rem;
    text-align: center;
    color: rgba(255, 255, 255, 0.7);
    font-size: 0.875rem;
}

.exit-info .key {
    display: inline-block;
    background: rgba(255, 59, 59, 0.8);
    color: #fff;
    padding: 0.25rem 0.5rem;
    border-radius: 3px;
    font-weight: 700;
    margin: 0 0.25rem;
}

@keyframes slideIn {
    from {
        opacity: 0;
        transform: translateX(20px);
    }
    to {
        opacity: 1;
        transform: translateX(0);
    }
}
</style>
