import {progressDefaultCircles} from "../../../../../DefaultDatas";
import {CircleProgress} from "../../CircleProgress";
import {ColorPicker} from "./ColorPicker";
import {createStore, produce} from "solid-js/store";
import {useSettingsStorageDispatch, useSettingsStorageState} from "../../../Contexts/SettingsStorage";
import {createEffect, onMount} from "solid-js";
import {translate} from "../../../../Utils/Translate";


export const RangeSlider = (props) =>{

    const options = () => props?.options

    const handleChange = (e) =>{
        props?.setSize(e.target.value)
    }


    return(
        <div class="flex items-center justify-center gap-4 relative pt-1">
            <label for="rangeWidth" class="form-label uppercase">{props?.name}</label>
            <input
                type="range"
                class="
                      form-range
                      appearance-none
                      rounded-full
                      w-1/2
                      h-2
                      p-0
                      bg-[#0087D0]
                      focus:outline-none focus:ring-0 focus:shadow-none
                    "
                min={options().min}
                max={options().max}
                step={options().step}
                value={props?.currentSize ? props?.currentSize : props?.defaultValue}
                id="rangeWidth"
                onChange={handleChange}
            />
        </div>
    )
}

export const Status = (props) => {
    const [circleProgressColors,setCircleProgressColors] = createStore(progressDefaultCircles)
    const settingsStorageState = useSettingsStorageState();
    const { getCurrentColor,setCurrentCircleWidth } = useSettingsStorageDispatch();



    const currentElement = () => settingsStorageState.selectedElementName
    const currentWidth = () => settingsStorageState.currentCircleWidth

    return (
        <>
            <div class="p-2 flex flex-col gap-6">
                <For each={circleProgressColors}>{(progress, i) =>
                    <div class="flex justify-evenly items-center">
                        <h2 class="w-[100px] uppercase">{translate(progress.name,"Status")}</h2>
                        <div style={"transform: scale(1.5);padding-right: 30px"}>
                            <CircleProgress circleWidth={currentWidth()} showPercent={false} icon={progress.icon} progressLevel={progress.progressLevel} color={getCurrentColor(progress.name,"statusColors")} />
                        </div>
                        <ColorPicker isActive={currentElement() === progress.name} name={progress.name} />
                    </div>
                }</For>
                <RangeSlider currentSize={currentWidth()} setSize={setCurrentCircleWidth} name={translate("circleWidth","Status")} defaultValue={2.5} options={{min: "2", max:"5", step: "0.5"}}/>
            </div>
        </>
    );
};