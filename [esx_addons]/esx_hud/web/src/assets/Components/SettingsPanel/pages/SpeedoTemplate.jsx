import {Speedo} from "../../Speedo";
import {speedoDefaultColors, vehDefaultData} from "../../../../../DefaultDatas";
import {createStore} from "solid-js/store";
import {ColorPicker} from "./ColorPicker";
import {useSettingsStorageDispatch, useSettingsStorageState} from "../../../Contexts/SettingsStorage";
import {translate} from "../../../../Utils/Translate";
import { RangeSlider } from "./Status";

export const SpeedoTemplate = (props) => {

    const [speedoColors, setSpeedoColors] = createStore(speedoDefaultColors)
    const settingsStorageState = useSettingsStorageState();
    const { setCurrentSpeedoSize } = useSettingsStorageDispatch();
    const currentElement = () => settingsStorageState.selectedElementName
    const currentSize = () => settingsStorageState.currentSpeedoSize

    return (
        <div class="flex flex-col gap-5">
            <div class="flex px-5 gap-[3rem]">
                <div class="relative z-10 p-2 flex flex-col gap-6 overflow-auto max-h-72">
                    <For each={speedoColors}>{(progress, i) =>
                        <div class="flex justify-between items-center gap-2">
                            <h2 class="uppercase">{translate(progress.name,"Speedo")}</h2>
                            <ColorPicker isActive={currentElement() === progress.name} name={progress.name}/>
                        </div>
                    }</For>
                </div>
                <div class="flex items-center justify-center">
                    <Speedo template="true" vehData={vehDefaultData}/>
                </div>
            </div>
            <div>
                <RangeSlider currentSize={currentSize()} setSize={setCurrentSpeedoSize} name={translate("resize-speedo","Speedo")} defaultValue={0.9} options={{min: 0.1, max:1.0, step: 0.1}}/>
            </div>
        </div>
    );
};
