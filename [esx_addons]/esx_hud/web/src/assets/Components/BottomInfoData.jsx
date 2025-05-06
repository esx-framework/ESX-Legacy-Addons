import {For} from "solid-js";
import {useHudStorageDispatch, useHudStorageState} from "../Contexts/HudStorage";
import {useSettingsStorageState} from "../Contexts/SettingsStorage";

const MicIcon = (props) => {
    const mic = () => props.state ? 'orange' : 'white'
    const radio = () => props.radio ?  'red': 'white'

    return(
        <svg width="21" height="21" viewBox="0 0 21 21" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path class="ease-in duration-200" d="M6.5625 3.9375C6.5625 2.89321 6.97734 1.89169 7.71577 1.15327C8.45419 0.414843 9.45571 0 10.5 0C11.5443 0 12.5458 0.414843 13.2842 1.15327C14.0227 1.89169 14.4375 2.89321 14.4375 3.9375V10.5C14.4375 11.5443 14.0227 12.5458 13.2842 13.2842C12.5458 14.0227 11.5443 14.4375 10.5 14.4375C9.45571 14.4375 8.45419 14.0227 7.71577 13.2842C6.97734 12.5458 6.5625 11.5443 6.5625 10.5V3.9375Z" fill={props.state ? mic() : radio()}/>
            <path class="ease-in duration-200" d="M4.59375 8.53125C4.7678 8.53125 4.93472 8.60039 5.05779 8.72346C5.18086 8.84653 5.25 9.01345 5.25 9.1875V10.5C5.25 11.8924 5.80312 13.2277 6.78769 14.2123C7.77226 15.1969 9.10761 15.75 10.5 15.75C11.8924 15.75 13.2277 15.1969 14.2123 14.2123C15.1969 13.2277 15.75 11.8924 15.75 10.5V9.1875C15.75 9.01345 15.8191 8.84653 15.9422 8.72346C16.0653 8.60039 16.2322 8.53125 16.4062 8.53125C16.5803 8.53125 16.7472 8.60039 16.8703 8.72346C16.9934 8.84653 17.0625 9.01345 17.0625 9.1875V10.5C17.0625 12.1269 16.4582 13.6958 15.3669 14.9023C14.2756 16.1088 12.775 16.867 11.1562 17.0297V19.6875H15.0938C15.2678 19.6875 15.4347 19.7566 15.5578 19.8797C15.6809 20.0028 15.75 20.1697 15.75 20.3438C15.75 20.5178 15.6809 20.6847 15.5578 20.8078C15.4347 20.9309 15.2678 21 15.0938 21H5.90625C5.7322 21 5.56528 20.9309 5.44221 20.8078C5.31914 20.6847 5.25 20.5178 5.25 20.3438C5.25 20.1697 5.31914 20.0028 5.44221 19.8797C5.56528 19.7566 5.7322 19.6875 5.90625 19.6875H9.84375V17.0297C8.22502 16.867 6.72443 16.1088 5.63309 14.9023C4.54175 13.6958 3.93748 12.1269 3.9375 10.5V9.1875C3.9375 9.01345 4.00664 8.84653 4.12971 8.72346C4.25278 8.60039 4.4197 8.53125 4.59375 8.53125Z" fill={props.state ? mic() : radio()}/>
        </svg>
    )
}
const GpsIcon = () => <svg width="21" height="21" viewBox="0 0 21 21" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M10.5 2C7.45929 2 5 4.817 5 8.3C5 13.025 10.5 20 10.5 20C10.5 20 16 13.025 16 8.3C16 4.817 13.5407 2 10.5 2ZM10.5 10.55C9.41571 10.55 8.53571 9.542 8.53571 8.3C8.53571 7.058 9.41571 6.05 10.5 6.05C11.5843 6.05 12.4643 7.058 12.4643 8.3C12.4643 9.542 11.5843 10.55 10.5 10.55Z" fill="white"/>
</svg>

const Point = (props) =>{
    return(
        <div class={`${props.state ? 'bg-green-400' : 'bg-green-900'} ease-in duration-500 w-2 h-2 rounded-full border border-solid border-gray-900`}></div>
    )
}


export const BottomInfoData = (props) => {

    const hudStorageState = useHudStorageState();
    const { currentMicRangeStatus } = useHudStorageDispatch();
    const settingsStorageState = useSettingsStorageState();
    const settings = () => settingsStorageState.settings

    const hud = () => hudStorageState.hud
    const voice = () => hud().voice

    return (
        <div className="flex flex-col gap-2 absolute left-1/4 bottom-10">

            <Show keyed when={!settings().Voice}>
                <div className="flex gap-2 items-center">
                    <MicIcon state={voice().mic} radio={voice().radio}/>
                    <div class="flex flex-col gap-1 -rotate-180">
                        <For each={currentMicRangeStatus()}>{(range, i) =>
                            <Point state={range}/>
                        }</For>
                    </div>
                </div>
            </Show>

            <Show keyed when={!settings().Position}>
                <div className="flex gap-4 items-center">
                    <GpsIcon/>
                    <p className="font-bold text-white">{hud().streetName}</p>
                </div>
            </Show>
        </div>
    );
};