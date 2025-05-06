import {createMemo, Show} from "solid-js";
import {useHudStorageState} from "../Contexts/HudStorage";
import {useSettingsStorageDispatch, useSettingsStorageState} from "../Contexts/SettingsStorage";

export const CircleProgress = (props) => {
    return (
        <div className={`w-10 flex flex-col justify-center items-center`} >
            <div className="relative w-10 h-10">
                <svg width="40" height="40" viewPort="0 0 100 100" version="1.1" xmlns="http://www.w3.org/2000/svg">
                    <circle className="ease-in duration-300"  r="15" cx="20" cy="20" stroke={props?.color} stroke-opacity="0.1" fill="transparent" stroke-width={props?.circleWidth} stroke-dashoffset="0"></circle>
                    <circle className="ease-in duration-300"  id="bar" r="15" cx="20" cy="20" fill-opacity="0.3" fill={props?.color} stroke-dasharray={`${props?.progressLevel} 100`} stroke-width={props?.circleWidth} stroke={props?.color} stroke-dashoffset="0"></circle>
                </svg>
                {props?.icon}
            </div>
            <Show keyed when={props?.showPercent}>
                <p className="text-xs font-normal text-white">{props.progressLevel}%</p>
            </Show>
        </div>
    );
};

export const CircleProgressContainer = (props) =>{

    const hudStorageState = useHudStorageState();
    const settingsStorageState = useSettingsStorageState();
    const { getCurrentColor } = useSettingsStorageDispatch();
    const showSpeedo = () => hudStorageState.speedo.show
    const settings = () => settingsStorageState.settings
    const currentWidth = () => settingsStorageState.currentCircleWidth

    const getGoodClassName = createMemo(()=>{
        if(!showSpeedo()){
            if(settings().MinimapOnFoot){
                return 'flex-col-status'
            }
        }
        if(!settings().CenterStatuses){
            return 'center-statuses'
        }
        return 'flex-status'
    })

    return(
        <Show when={!settings().Status} keyed>
            <div className={getGoodClassName()}>
                <For each={hudStorageState.status}>{(progress, i) =>
                    <Show keyed when={progress.progressLevel > 0}>
                        <CircleProgress showPercent={!settings().StatusPercent} icon={progress.icon} progressLevel={progress.progressLevel} color={getCurrentColor(progress.name,"statusColors")} circleWidth={currentWidth()} />
                    </Show>
                }</For>
            </div>
        </Show>
    )
}