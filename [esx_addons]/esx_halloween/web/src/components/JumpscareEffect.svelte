<script lang="ts">
let { visible = $bindable(false), soundVolume = $bindable(0.8) } = $props();

let timeoutId: number | null = null;
let audio: HTMLAudioElement | null = null;

$effect(() => {
    if (visible) {
        audio = new Audio('./assets/scream.wav');
        audio.volume = soundVolume;
        audio.play().catch(err => console.error('Jumpscare sound error:', err));

        timeoutId = window.setTimeout(() => {
            visible = false;
        }, 2000);
    }

    return () => {
        if (timeoutId) {
            clearTimeout(timeoutId);
            timeoutId = null;
        }
        if (audio) {
            audio.pause();
            audio = null;
        }
    };
});
</script>

{#if visible}
<div class="jumpscare-overlay">
    <div class="jumpscare-content">
        <img src="./assets/pumpkin.webp" alt="scary" class="jumpscare-image" />
        <div class="jumpscare-text">BOO!</div>
    </div>
</div>
{/if}

<style>
.jumpscare-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.95);
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
    animation: flashIn 0.1s ease, shake 0.5s ease;
}

.jumpscare-content {
    text-align: center;
    animation: scaleUp 0.3s ease;
}

.jumpscare-image {
    width: 200px;
    height: 200px;
    filter: drop-shadow(0 0 40px #ff0000) brightness(1.5);
    animation: pulse 0.2s ease infinite;
}

.jumpscare-text {
    font-size: 4rem;
    color: #ff0000;
    font-family: 'Creepster', cursive;
    margin-top: 1rem;
    text-shadow: 0 0 20px #ff0000;
    animation: glitch 0.3s ease infinite;
}

@keyframes flashIn {
    0% { opacity: 0; }
    100% { opacity: 1; }
}

@keyframes shake {
    0%, 100% { transform: translate(0, 0); }
    10%, 30%, 50%, 70%, 90% { transform: translate(-10px, 0); }
    20%, 40%, 60%, 80% { transform: translate(10px, 0); }
}

@keyframes scaleUp {
    from {
        transform: scale(0.5);
        opacity: 0;
    }
    to {
        transform: scale(1);
        opacity: 1;
    }
}

@keyframes pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.1); }
}

@keyframes glitch {
    0% {
        text-shadow: 0 0 20px #ff0000;
    }
    25% {
        text-shadow: -5px 0 20px #ff0000, 5px 0 20px #00ff00;
    }
    50% {
        text-shadow: 5px 0 20px #0000ff, -5px 0 20px #ff0000;
    }
    75% {
        text-shadow: 0 5px 20px #ff0000, 0 -5px 20px #00ff00;
    }
    100% {
        text-shadow: 0 0 20px #ff0000;
    }
}
</style>
