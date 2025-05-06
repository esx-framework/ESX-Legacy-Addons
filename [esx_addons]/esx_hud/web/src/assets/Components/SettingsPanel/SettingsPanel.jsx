import {Routes, Route, useNavigate, A} from "@solidjs/router"
import {Settings} from "./pages/Settings";
import {
    defaultMenuButtons
} from "../../../../DefaultDatas";
import {SpeedoTemplate} from "./pages/SpeedoTemplate";
import {Status} from "./pages/Status";
import {createSignal, onMount, Show} from "solid-js";
import {useSettingsStorageDispatch, useSettingsStorageState} from "../../Contexts/SettingsStorage";
import {Nui} from "../../../Utils/Nui";
import {translate} from "../../../Utils/Translate";

const MainPage = (props) =>{
    const currentPath = () => props?.currentPath()
    return(
        <div class="flex gap-4 justify-center border-b-2 border-[#0087D0] border-solid p-4">
            <For each={defaultMenuButtons}>{(menu, i) =>
                <A className={`p-2 ${currentPath() === menu.path ? 'bg-blue-800' : 'bg-sky-400'} uppercase rounded-md bg-[#0087D0] hover:scale-125 ease-out duration-300`} href={`/${menu.path}`} onClick={() => props?.onMenuClick(menu)}>{translate(menu.name)}</A>
            }</For>
        </div>
    )
}

const ExitIcon = (props) => <svg width="30" height="30" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 352 512"><path class="fill-gray-800 hover:fill-red-700 hover:ease-in duration-100" d="M242.72 256l100.07-100.07c12.28-12.28 12.28-32.19 0-44.48l-22.24-22.24c-12.28-12.28-32.19-12.28-44.48 0L176 189.28 75.93 89.21c-12.28-12.28-32.19-12.28-44.48 0L9.21 111.45c-12.28 12.28-12.28 32.19 0 44.48L109.28 256 9.21 356.07c-12.28 12.28-12.28 32.19 0 44.48l22.24 22.24c12.28 12.28 32.2 12.28 44.48 0L176 322.72l100.07 100.07c12.28 12.28 32.2 12.28 44.48 0l22.24-22.24c12.28-12.28 12.28-32.19 0-44.48L242.72 256z"/></svg>

const ResetIcon = () => <svg width="20" height="20" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path fill="white" d="M105.1 202.6c7.7-21.8 20.2-42.3 37.8-59.8c62.5-62.5 163.8-62.5 226.3 0L386.3 160H336c-17.7 0-32 14.3-32 32s14.3 32 32 32H463.5c0 0 0 0 0 0h.4c17.7 0 32-14.3 32-32V64c0-17.7-14.3-32-32-32s-32 14.3-32 32v51.2L414.4 97.6c-87.5-87.5-229.3-87.5-316.8 0C73.2 122 55.6 150.7 44.8 181.4c-5.9 16.7 2.9 34.9 19.5 40.8s34.9-2.9 40.8-19.5zM39 289.3c-5 1.5-9.8 4.2-13.7 8.2c-4 4-6.7 8.8-8.1 14c-.3 1.2-.6 2.5-.8 3.8c-.3 1.7-.4 3.4-.4 5.1V448c0 17.7 14.3 32 32 32s32-14.3 32-32V396.9l17.6 17.5 0 0c87.5 87.4 229.3 87.4 316.7 0c24.4-24.4 42.1-53.1 52.9-83.7c5.9-16.7-2.9-34.9-19.5-40.8s-34.9 2.9-40.8 19.5c-7.7 21.8-20.2 42.3-37.8 59.8c-62.5 62.5-163.8 62.5-226.3 0l-.1-.1L125.6 352H176c17.7 0 32-14.3 32-32s-14.3-32-32-32H48.4c-1.6 0-3.2 .1-4.8 .3s-3.1 .5-4.6 1z"/></svg>

const SaveIcon = () => <svg width="20" height="20" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="white" d="M64 32C28.7 32 0 60.7 0 96V416c0 35.3 28.7 64 64 64H384c35.3 0 64-28.7 64-64V173.3c0-17-6.7-33.3-18.7-45.3L352 50.7C340 38.7 323.7 32 306.7 32H64zm0 96c0-17.7 14.3-32 32-32H288c17.7 0 32 14.3 32 32v64c0 17.7-14.3 32-32 32H96c-17.7 0-32-14.3-32-32V128zM224 416c-35.3 0-64-28.7-64-64s28.7-64 64-64s64 28.7 64 64s-28.7 64-64 64z"/></svg>

const SaveResetButtons = (props) =>{

    const click = () => props?.onSaveAndResetButtonClick()
    const clickReset = () => props?.onSaveAndResetButtonClick("reset")
    const name = () => props?.selectedName
    const title = () => props?.currentSelectedMenu
    const showEdit = () => props?.showEdit
    const toggleShowPanel = () => props?.toggleShowPanel()

    //Exit right top corner
    const handleClickClose = () => {
        toggleShowPanel()
        Nui.send("closePanel")
    }

    document.addEventListener('keyup',function (e){
        if(e.key === "Escape"){
            handleClickClose()
        }
    })

    return(
        <>
            <div class="relative flex justify-evenly items-center mt-5 z-10">
                <button class="p-2 bg-red-700 rounded-md hover:scale-125 ease-out duration-300" onClick={clickReset}>
                    <div class="flex gap-2 items-center justify-center">
                        <ResetIcon/>
                        {translate("reset")}
                    </div>
                </button>
                <div class="uppercase text-3xl">{title().length > 0 ? translate(title()) : ''}</div>
                <button class="p-2 bg-green-700 rounded-md hover:scale-125 ease-out duration-300" onClick={click}>
                    <div class="flex gap-2 items-center justify-center">
                        <SaveIcon/>
                        {translate("save")}
                    </div>
                </button>
            </div>
            <button class="absolute top-5 right-5" onClick={handleClickClose}>
                <ExitIcon/>
            </button>
            <Show keyed when={showEdit()}>
                <h1 class="mb-5 mt-5 font-bold">
                    {
                        name().length > 0 ? `${translate("currentedit")} ${name()}` : translate("info")
                    }
                </h1>
            </Show>
        </>
    )
}


// if detect changes return true else return false
const checkObjectValueChanges = (checkedObject,defaultObject) =>{
    let changes = false
    Object.keys(defaultObject).forEach((data)=>{
        checkedObject.forEach((status)=>{
            if(status.name === data){
                if(status.color !== defaultObject[data]){
                    changes = true
                }
            }
        })
    })
    return changes
}

export const SettingsPanel = () =>{

    const settingsStorageState = useSettingsStorageState();
    const [showEdit,setShowEdit] = createSignal(true)
    const [currentPath,setCurrentPath] = createSignal('status')
    const { setSelectedMenu,resetColors ,saveColors,saveSettings,resetSettings,setSelectedElement, toggleShowPanel } = useSettingsStorageDispatch();
    const currentSelectedElementName = () => settingsStorageState.selectedElementName
    const showPanel = () => settingsStorageState.showPanel

    const selectedMenuName = () => settingsStorageState.selectedMenuName
    const navigate = useNavigate()

    const handleMenuClick = (currentMenu) =>{
        if(currentMenu.name === selectedMenuName()){
            return
        }
        //Remove picker element in DOM if change route path
        const allPickerElement = document.querySelectorAll('.custom-colorpicker')
        if(allPickerElement.length > 0)
            allPickerElement.forEach(e => e.remove());

        setSelectedMenu(currentMenu.name) //TODO: NEW
        setSelectedElement("")
        setShowEdit(currentMenu.name !== "Settings")
        setCurrentPath(currentMenu.path)
    }

    onMount(()=>{
        handleMenuClick({name: "Status", path:"status"})
        navigate('/status', { replace: true });
    })

    const handleClickSaveAndReset = (type) =>{
        setSelectedElement('')
        if(type === "reset"){
            if(selectedMenuName() === "Settings"){
                resetSettings()
                return;
            }
            resetColors()
            return;
        }

        if(selectedMenuName() === "Settings"){
            saveSettings()
            return;
        }
        saveColors()
    }

    return(
        <>
            <div class={`relative bg-[#17191A] w-[650px] rounded-[25px] pb-4 ease-in duration-500 z-30 ${showPanel() ? 'slideDown' : 'slideUp'}`}>
                <MainPage currentPath={currentPath} onMenuClick={handleMenuClick}/>
                <SaveResetButtons toggleShowPanel={toggleShowPanel} showEdit={showEdit()} currentSelectedMenu={selectedMenuName()} selectedName={currentSelectedElementName()} onSaveAndResetButtonClick={handleClickSaveAndReset}/>
                <Routes>
                    <Route path="/status" component={Status}/>
                    <Route path="/speedo" component={SpeedoTemplate}/>
                    <Route path="/settings" component={Settings}/>
                </Routes>
            </div>
        </>
    )
}


