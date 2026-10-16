interface GhostState {
    choiceVisible: boolean;
    hudVisible: boolean;
    jumpscareVisible: boolean;
    maxDuration: number;
    exitKey: string;
    scareKey: string;
    forced: boolean;
    soundVolume: number;
}

class GhostManager {
    state = $state<GhostState>({
        choiceVisible: false,
        hudVisible: false,
        jumpscareVisible: false,
        maxDuration: 600000,
        exitKey: 'X',
        scareKey: 'E',
        forced: false,
        soundVolume: 0.8
    });

    showChoice(forced: boolean = false) {
        this.state.choiceVisible = true;
        this.state.forced = forced;
    }

    hideChoice() {
        this.state.choiceVisible = false;
    }

    showHUD(maxDuration: number, exitKey: string = 'X', scareKey: string = 'E') {
        this.state.hudVisible = true;
        this.state.maxDuration = maxDuration;
        this.state.exitKey = exitKey;
        this.state.scareKey = scareKey;
    }

    hideHUD() {
        this.state.hudVisible = false;
    }

    triggerJumpscare(soundVolume: number = 0.8) {
        this.state.jumpscareVisible = true;
        this.state.soundVolume = soundVolume;
    }

    hideJumpscare() {
        this.state.jumpscareVisible = false;
    }
}

export const ghostManager = new GhostManager();
