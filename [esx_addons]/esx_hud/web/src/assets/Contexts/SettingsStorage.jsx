import {createContext, onMount, useContext} from "solid-js";
import {createStore, produce} from "solid-js/store";
import {disableDefaultConfig, progressDefaultCircles, speedoDefaultColors} from "../../../DefaultDatas";
import {Nui} from "../../Utils/Nui";

const StateContext = createContext()
const DispatchContext = createContext()

const initialState = {
    statusColors:[
        {
            name: "healthBar",
            color: "red"
        },
        {
            name: "armorBar",
            color: "blue"
        },
        {
            name: "drinkBar",
            color: "lightblue"
        },
        {
            name: "foodBar",
            color: "yellow"
        },
        {
            name: "oxygenBar",
            color: "pink"
        },
        {
            name: "staminaBar",
            color: "green"
        }
    ],
    infoColors: [
        {
            name: "money-text-color",
            color: "blue"
        },
        {
            name: "bank-text-color",
            color: "orange"
        },
        {
            name: "job-text-color",
            color: "red"
        }
    ],
    speedoColors:[
        {
            name: "segment-color",
            color: "#eee"
        },
        {
            name:"segment-progress-color",
            color:"green"
        },
        {
            name: "number-color",
            color: "#eee"
        },
        {
            name: "danger-color",
            color: "#ff113a"
        },
        {
            name:"danger-progress-color",
            color:"pink"
        },
        {
            name: "number-danger-color",
            color: "#da0b64"
        },
        {
            name: "speedo-progress-color",
            color: "orange"
        },
        {
            name: "damage-progress-color",
            color: "#1be70d"
        },
        {
            name: "engine-icon-color",
            color: "#FEC32C"
        },

        {
            name: "tempomat-icon-color",
            color: "#FEC32C"
        },
        {
            name: "light-icon-color",
            color: "#FEC32C"
        },
        {
            name: "door-icon-color",
            color: "#FEC32C"
        },
        {
            name: "fuel-icon-color",
            color: "white"
        },
        {
            name: "fuel-level-color",
            color: "pink"
        },
        {
            name: "mileage-level-color",
            color: "green"
        },
        {
            name: "unit-color",
            color: "red"
        },
        {
            name: "current-speed-color",
            color: "pink"
        },
        {
            name: "left-right-index-color",
            color: "#00B065"
        },
        {
            name: "damage-icon-color",
            color: "white"
        },
        {
            name: "speedo-background-color",
            color: "rgba(0,0,0,.5)"
        },
        {
            name: "speedo-outer-circle-color",
            color: "#242222"
        },
        {
            name: "speedo-nooble-color",
            color: "#48a3cb"
        },
        {
            name: "speedo-nooble-container",
            color: "#1f2937"
        },
        {
            name: "speedo-seatbelt-icon-color",
            color: "#D22B2B"
        }
    ],
    settings:{
        Status: false,
        Vehicle: false,
        Weapon: false,
        Position: false,
        Voice: false,
        Money: false,
        Info: false,
        IndicatorSound: false,
        IndicatorSeatbeltSound: false,
        VehicleHandlers:false,
        MinimapOnFoot:false,
        Needle: false,
        Kmh: true,
        StatusPercent:false,
        CenterStatuses:false
    },
    disableDefaultConfig:{
        Status: false,
        Vehicle: false,
        Weapon: false,
        Position: false,
        Voice: false,
        Money: false,
        Info: false,
        IndicatorSound: false,
        IndicatorSeatbeltSound: false,
        VehicleHandlers:false,
        MinimapOnFoot:false,
        Needle:false,
        Kmh: true,
        StatusPercent:false,
        CenterStatuses:false
    },
    pickedColor: "",
    currentCircleWidth: "",
    currentSpeedoSize: "",
    selectedElementName: "",
    selectedMenuName: "",
    showPanel: false,
    defaultConfigs:{
        ServerLogo: "",
        Kmh: true
    }
}

export default function SettingsStorage(props){
    const [store,setStore] = createStore(initialState)

    /**
     * Init load check if exist localstorage load saved values
     */
    onMount(()=>{
        const datas = ["statusColors","speedoColors","settings", "currentCircleWidth", "currentSpeedoSize"]
        datas.forEach((dataKey)=>{
            let currentData = handleLocalStorage(dataKey,"get")
            if(!currentData){
                return
            }
            setStore(dataKey, currentData)

            if(dataKey === "speedoColors"){
                changeThemeColors(currentData)
            }

            if(dataKey === "currentSpeedoSize"){
                setCurrentSpeedoSize(currentData)
            }
        })
    })

    /**
     * Set current selected menu name
     * @param currentMenuName current selected menu name
     */
    function setSelectedMenu(currentMenuName){
        setStore("selectedMenuName",currentMenuName)
    }

    /*COLOR PICKER FUNCTIONS*/

    /**
     * Set current picked color in colorpicker
     * @param newColor picked color
     */
    function setCurrentPickedColor(newColor){
        setStore("pickedColor", newColor)
        updateColors()
    }

    /**
     * Set current width value in range slider
     * @param newWidth current width value
     */
    function setCurrentCircleWidth(newWidth){
        setStore("currentCircleWidth", newWidth)
    }

    /**
     * Set current size value in range slider
     * @param newWidth current width value
     */
        function setCurrentSpeedoSize(newSize){
            setStore("currentSpeedoSize", newSize)
            const r = document.querySelector(':root');
            r.style.setProperty('--speedo-scale-size', newSize);
        }

    /**
     * Set current selected element name
     * @param selectedName current selected element name
     */
    function setSelectedElement(selectedName){
        setStore("selectedElementName", selectedName)
    }

    /**
     * Handle update colors by current selected menu name
     */
    function updateColors(){
        const currentSelectedMenu = store.selectedMenuName ? store.selectedMenuName.toLowerCase() : 'status'
        const currentPickedColor = store.pickedColor
        const currentSelectedCircleName = store.selectedElementName
        setStore(
            `${currentSelectedMenu}Colors`,
            currentStatus => currentStatus.name === currentSelectedCircleName,
            produce((currentStatus) => (currentStatus.color = currentPickedColor)),
        );

        if(currentSelectedMenu === "speedo"){
            changeThemeColors(store.speedoColors)
        }
    }

    /*
    * Get current element color in current store
    * */
    function getCurrentColor(editElementName,currentStoreName){
        const currentStore = store[currentStoreName]
        return currentStore?.find((data) => data.name === editElementName).color
    }

    /**
     * Set param colors :root stlye in css
     * Handle array and objects
     * @param colors current default colors array
     */
    function changeThemeColors(colors){
        const r = document.querySelector(':root');
        if(Array.isArray(colors)){
            colors.forEach((color)=>{
                r.style.setProperty(`--${color.name}`,color.color)
            })
            return
        }

        Object.keys(colors).forEach((color)=>{
            r.style.setProperty(`--${color}`,colors[color])
        })

    }

    /*
    * Reset all colors and remove localstore key by current selected menu name
    * */
    function resetColors(){
        const currentSelectedMenu = store.selectedMenuName ? store.selectedMenuName.toLowerCase() : 'status'
        const selectMenu = `${currentSelectedMenu}Colors`
        let defaultData = progressDefaultCircles
        if(currentSelectedMenu === "speedo"){
            changeThemeColors(speedoDefaultColors)
            defaultData = speedoDefaultColors
            handleLocalStorage("currentSpeedoSize","remove")
            setCurrentSpeedoSize(0.9)
        }

        defaultData.forEach((data)=>{
            setStore(
                selectMenu,
                currentData => currentData.name === data.name,
                produce((currentData) => (currentData.color = data.color)),
            );
        })

        handleLocalStorage(selectMenu,"remove")
        if(currentSelectedMenu === "status"){
            handleLocalStorage("currentCircleWidth","remove")
        }
    }

    /**
     * Save colors and localstorage key by current selected menu name
     */
    function saveColors(){
        const currentSelectedMenu = store.selectedMenuName ? store.selectedMenuName.toLowerCase() : 'status'

        const selectMenu = `${currentSelectedMenu}Colors`
        const newColors =  store[selectMenu].map((data) => {
            return {name: data.name, color: data.color}
        })

        if(currentSelectedMenu === "status"){
            handleLocalStorage("currentCircleWidth","add",store.currentCircleWidth)
        }
        handleLocalStorage("currentSpeedoSize","add",store.currentSpeedoSize)
        handleLocalStorage(selectMenu,"add",newColors)
    }

    /**
     * Handle local storage
     * @param key current setted key
     * @param type add/remove
     * @param newData if add you can use pass new save data
     */
    function handleLocalStorage(key,type = "add", newData = ""){
        if(type === "remove"){
            if(localStorage.hasOwnProperty(key)){
                localStorage.removeItem(key)
            }
            return
        }

        if(type === "get"){
            if(localStorage.hasOwnProperty(key)){
                return JSON.parse(localStorage.getItem(key))
            }
            return false;
        }

        localStorage.setItem(key,JSON.stringify(newData))
    }

    /**
     * Set settings in store by name
     * @param settingsName current settings name
     * @param settingsValue current settings value
     * @param storeKey current update store name
     */
    function setSettingsByName(settingsName,settingsValue, storeKey = "settings"){
        if(settingsValue !== undefined){
            setStore(storeKey,
                produce((data) => {
                    data[settingsName] = settingsValue
                }))
            return
        }
        setStore("settings",
            produce((data) => {
                data[settingsName] = !data[settingsName]
            }))
    }

    /**
     * Save settings in localstorage
     */
    function saveSettings(){
        const newSettings = store.settings
        if(!newSettings){
            return
        }
        handleLocalStorage("settings","add",newSettings)
        Nui.send("notify",{state: "save"})
    }

    /**
     * Reset settings in localstorage(remove by settings key)
     */
    function resetSettings(){
        setStore("settings", store.disableDefaultConfig)
        handleLocalStorage("settings","remove")
        Nui.send("notify",{state: "reset"})
    }

    function toggleShowPanel(){
        setStore("showPanel", !store.showPanel)
    }

    function setDefaultConfigs(newConfig) {
        changeThemeColors(newConfig["Colors"]["Info"])
        setSettingsByName("Kmh", newConfig["Default"].Kmh)
        setStore("defaultConfigs",newConfig["Default"])
        setStore("disableDefaultConfig",newConfig["Disable"])
        if(!handleLocalStorage("settings","get")){
            setStore("settings",newConfig["Disable"])
        }
    }

    return(
        <StateContext.Provider value={store}>
            <DispatchContext.Provider value={{
                setCurrentPickedColor,
                setSelectedElement,
                setSelectedMenu,
                getCurrentColor,
                changeThemeColors,
                resetColors,
                saveColors,
                setSettingsByName,
                saveSettings,
                resetSettings,
                toggleShowPanel,
                setDefaultConfigs,
                handleLocalStorage,
                setCurrentCircleWidth,
                setCurrentSpeedoSize
            }}>
                {props.children}
            </DispatchContext.Provider>
        </StateContext.Provider>
    )
}

export const useSettingsStorageState = () => useContext(StateContext)
export const useSettingsStorageDispatch = () => useContext(DispatchContext)



