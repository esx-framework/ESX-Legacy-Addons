import {createMemo} from "solid-js";
import {useSettingsStorageDispatch, useSettingsStorageState} from "../../../Contexts/SettingsStorage";
import {Nui} from "../../../../Utils/Nui";
import {translate} from "../../../../Utils/Translate";

const CheckBox = (props) =>{
    return(
        <div class="form-check flex">
            <input class="form-check-input appearance-none h-4 w-4 border border-gray-300 rounded-sm bg-gray-800 checked:bg-[#0087D0] checked:border-blue-600 focus:outline-none transition duration-200 mt-1 align-top bg-no-repeat bg-center bg-contain float-left mr-2 cursor-pointer" type="checkbox" value="" id={props?.name} checked={!props?.state} onClick={props?.click}/>
            <label class="form-check-label w-[75%]" for={props?.name}>
                {props?.name}
            </label>
        </div>
    )
}
const RadioButton = (props) =>{
    return(
        <div class="form-radio-check flex">
            <input class="form-radio-check-input appearance-none rounded-full h-4 w-4 border border-gray-300 bg-gray-800 checked:bg-[#0087D0] checked:border-blue-600 focus:outline-none transition duration-200 mt-1 align-top bg-no-repeat bg-center bg-contain float-left mr-2 cursor-pointer" type="radio" name="flexRadioDefault" id={props?.name} checked={props?.state} onClick={props?.click}/>
                <label class="form-check-label inline-block" for={props?.name}>
                    {props?.name}
                </label>
        </div>
    )
}

export const Settings = () => {

    const settingsStorageState = useSettingsStorageState();
    const {setSettingsByName} = useSettingsStorageDispatch();

    const settingsData = () => settingsStorageState.settings
    const defaultConfigs = () => settingsStorageState.defaultConfigs

    const radioButtonClick = (currentUnit) =>{
        const unit = currentUnit === "KMH"
        setSettingsByName("Kmh", unit, "defaultConfigs")
        Nui.send("unitChanged",{unit})
    }

    const handleClick = (name, value) =>{
        if(name === "MinimapOnFoot"){
            Nui.send("minimapSettingChanged",{changed: !value})
        }
        setSettingsByName(name)
    }


    //skip KMH key
    const formatDisableData = createMemo(() => Object.keys(settingsData()).filter((configName)=> configName !== "Kmh"))

    return (
        <>
            <div class="grid grid-cols-2 p-5 mt-10 gap-2">
                <For each={formatDisableData()}>{(configName, i) =>
                    <CheckBox name={translate(configName,"Settings")} state={settingsData()[configName]} click={()=>{handleClick(configName,settingsData()[configName])}}/>
                }</For>
            </div>
            <div class="flex gap-4 p-5">
                <h1>{translate("changeunit","Settings","Change unit:")}</h1>
                <RadioButton name={translate("kmh","Settings","KMH")} state={defaultConfigs().Kmh} click={()=>radioButtonClick("KMH")}/>
                <RadioButton name={translate("mph","Settings","MPH")} state={!defaultConfigs().Kmh} click={()=>radioButtonClick("MPH")}/>
            </div>
        </>
    );
};