import './InfoHud.css';
import { createMemo, createSignal, Show } from "solid-js";
import {useHudStorageState} from "../Contexts/HudStorage";
import {useSettingsStorageState} from "../Contexts/SettingsStorage";

const UserIcon =  () =><svg width="10" height="10" viewBox="0 0 10 10" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g clip-path="url(#clip0_22_173)">
        <path d="M4.92813 4.81703C5.58991 4.81703 6.16295 4.57968 6.63117 4.11139C7.09938 3.64317 7.33673 3.07028 7.33673 2.40844C7.33673 1.74682 7.09938 1.17385 6.63109 0.705487C6.1628 0.23735 5.58983 0 4.92813 0C4.26628 0 3.69339 0.23735 3.22517 0.705564C2.75696 1.17378 2.51953 1.74674 2.51953 2.40844C2.51953 3.07028 2.75696 3.64325 3.22525 4.11146C3.69354 4.5796 4.26651 4.81703 4.92813 4.81703Z" fill="#FD9800"/>
        <path d="M9.14314 7.68949C9.12964 7.49464 9.10233 7.28208 9.06212 7.05762C9.02153 6.83149 8.96927 6.61772 8.90671 6.42233C8.84209 6.22038 8.7542 6.02095 8.64555 5.82983C8.53279 5.63147 8.40034 5.45874 8.25172 5.3166C8.09631 5.16791 7.90604 5.04835 7.686 4.96115C7.46674 4.8744 7.22374 4.83046 6.96381 4.83046C6.86172 4.83046 6.763 4.87234 6.57234 4.99647C6.455 5.073 6.31775 5.1615 6.16455 5.25938C6.03355 5.34285 5.85609 5.42105 5.6369 5.49185C5.42305 5.56105 5.20592 5.59614 4.99161 5.59614C4.7773 5.59614 4.56024 5.56105 4.34616 5.49185C4.1272 5.42113 3.94974 5.34292 3.81889 5.25946C3.66714 5.16249 3.52982 5.07399 3.41072 4.9964C3.22029 4.87227 3.12149 4.83038 3.01941 4.83038C2.7594 4.83038 2.51648 4.8744 2.29729 4.96123C2.07741 5.04828 1.88705 5.16783 1.73149 5.31668C1.58295 5.45889 1.45042 5.63154 1.33781 5.82983C1.22925 6.02095 1.14136 6.2203 1.07666 6.4224C1.01418 6.61779 0.961914 6.83149 0.921326 7.05762C0.881119 7.28178 0.853806 7.49441 0.840302 7.68972C0.827026 7.88106 0.820312 8.07965 0.820312 8.28023C0.820312 8.80223 0.986252 9.22482 1.31348 9.53648C1.63666 9.84402 2.06429 10 2.5843 10H7.39937C7.91939 10 8.34686 9.8441 8.67012 9.53648C8.99742 9.22505 9.16336 8.80239 9.16336 8.28015C9.16328 8.07866 9.15649 7.87992 9.14314 7.68949Z" fill="#FD9800"/>
    </g>
    <defs>
        <clipPath id="clip0_22_173">
            <rect width="10" height="10" fill="white"/>
        </clipPath>
    </defs>
</svg>
const CircleInnerCircle = () => <svg width="11" height="11" viewBox="0 0 11 11" fill="none" xmlns="http://www.w3.org/2000/svg">
    <circle cx="5.5" cy="5.5" r="5.5" fill="white" fill-opacity="0.26"/>
    <circle cx="5.5" cy="5.5" r="2.75" fill="#FD9800"/>
</svg>
const Logo = () => <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
    <rect width="32" height="32" fill="url(#pattern0)"/>
    <defs>
        <pattern id="pattern0" patternContentUnits="objectBoundingBox" width="1" height="1">
            <use xlink:href="#image0_22_160" transform="scale(0.00125)"/>
        </pattern>
        <image id="image0_22_160" width="800" height="800" xlink:href="data:image/png;base64,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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgP+/PTgkAAAAABD0/7UrbAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAmwBUMyITguJMiQAAAABJRU5ErkJggg=="/>
    </defs>
</svg>
const ArrowIcon = () =><svg className="absolute right-0 top-1/2 -translate-y-1/2" width="9" height="17" viewBox="0 0 9 17" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M0.507812 8.5L9.00781 0V17L0.507812 8.5Z" fill="white"/>
</svg>
const AmmoIcon = () => <svg width="15" height="11" viewBox="0 0 15 11" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g clip-path="url(#clip0_22_190)">
        <path d="M11.3153 9.39321V4.30164C11.3153 4.20778 11.2496 4.13193 11.1682 4.13193H8.52062C8.43927 4.13193 8.37354 4.2078 8.37354 4.30164V9.39321C8.37354 9.48708 8.43929 9.56292 8.52062 9.56292V9.73263C8.43927 9.73263 8.37354 9.8085 8.37354 9.90234V10.5812C8.37354 10.6751 8.43929 10.7509 8.52062 10.7509H11.1682C11.2496 10.7509 11.3153 10.6751 11.3153 10.5812V9.90238C11.3153 9.80852 11.2496 9.73267 11.1682 9.73267V9.56296C11.2496 9.56294 11.3153 9.48708 11.3153 9.39321Z" fill="white"/>
        <path d="M8.66761 3.79267H11.021C11.1024 3.79267 11.1681 3.7168 11.1681 3.62296V3.45325C11.1681 2.33753 10.7061 1.27169 9.93257 0.601963C9.88021 0.556649 9.80843 0.556649 9.75607 0.601963C8.98252 1.27169 8.52051 2.33751 8.52051 3.45325V3.62296C8.52053 3.7168 8.58626 3.79267 8.66761 3.79267Z" fill="white"/>
    </g>
    <g clip-path="url(#clip1_22_190)">
        <path d="M5.88441 9.39321V4.30164C5.88441 4.20778 5.81866 4.13193 5.73733 4.13193H3.08971C3.00836 4.13193 2.94263 4.2078 2.94263 4.30164V9.39321C2.94263 9.48708 3.00838 9.56292 3.08971 9.56292V9.73263C3.00836 9.73263 2.94263 9.8085 2.94263 9.90234V10.5812C2.94263 10.6751 3.00838 10.7509 3.08971 10.7509H5.73733C5.81868 10.7509 5.88441 10.6751 5.88441 10.5812V9.90238C5.88441 9.80852 5.81866 9.73267 5.73733 9.73267V9.56296C5.81866 9.56294 5.88441 9.48708 5.88441 9.39321Z" fill="white"/>
        <path d="M3.2367 3.79267H5.59014C5.67148 3.79267 5.73722 3.7168 5.73722 3.62296V3.45325C5.73722 2.33753 5.27521 1.27169 4.50166 0.601963C4.4493 0.556649 4.37752 0.556649 4.32516 0.601963C3.55161 1.27169 3.0896 2.33751 3.0896 3.45325V3.62296C3.08962 3.7168 3.15535 3.79267 3.2367 3.79267Z" fill="white"/>
    </g>
    <defs>
        <clipPath id="clip0_22_190">
            <rect width="8.82541" height="10.1832" fill="white" transform="translate(5.43115 0.567383)"/>
        </clipPath>
        <clipPath id="clip1_22_190">
            <rect width="8.82541" height="10.1832" fill="white" transform="translate(0 0.567383)"/>
        </clipPath>
    </defs>
</svg>

const FirstRow = (props) =>{
    return(
        <Show keyed when={!props?.hide}>
            <div className="flex gap-2 mb-4">
                <div className="flex gap-2 items-center">
                    <UserIcon/>
                    <p className="font-bold w-10 text-white">#{props?.playerId}</p>
                </div>
                <div className="flex gap-2 items-center">
                    <CircleInnerCircle/>
                    <p className="font-bold text-white">{props?.onlinePlayers}</p>
                </div>
                <div className="ml-4">
                    {
                        props?.serverLogo ? <img class="w-5/12" alt="no picture" src={props?.serverLogo}/> : <Logo/>
                    }
                </div>
            </div>
        </Show>
    )
}

const SecondRow = (props) =>{
    return(
        <Show keyed when={!props?.hide}>
            <div className="flex flex-col">
                <div className="relative">
                    <ArrowIcon/>
                    <p className="text-2xl moneyTextColor font-bold">${props.money}</p>
                </div>

                <div className="relative">
                    <ArrowIcon/>
                    <p className="text-xl bankTextColor font-bold">${props.bank}</p>
                </div>

                <div className="relative">
                    <ArrowIcon/>
                    <p className="text-xl jobTextColor font-bold">{props.jobLabel}</p>
                </div>
            </div>
        </Show>
    )
}

const ThirdRow = (props) =>{
    const disableWeapon = () => props?.hide ? false : props?.use
    const isWeaponMelee = () => props?.isWeaponMelee
    const [currentWeaponImage,setCurrentWeaponImage] = createSignal('')
    const allImages = import.meta.glob("../weapons/*.png")

    createMemo(async () => {
        if(!disableWeapon()){
            return
        }
        const currentImage = () => props?.image ? props?.image : 'pistol'
        const name = `../weapons/${currentImage().replace(/ /g, '')}.png`

        if(!allImages.hasOwnProperty(name)){
            setCurrentWeaponImage('')
            return  ''
        }
        const match = allImages[name];
        match().then((currentImage)=>{
            setCurrentWeaponImage(currentImage.default)
        }).catch((err)=>{
            console.error(err)
            setCurrentWeaponImage('')
            return ''
        })
    });

    return(
        <Show when={disableWeapon()} keyed>
            <div className="relative top-6">
                <div className="relative">
                    <ArrowIcon />
                    <Show when={currentWeaponImage().length > 0}>
                        <img class="w-1/2" src={currentWeaponImage()}  alt="no picture"/>
                    </Show>
                </div>
                <div className="flex gap-2 relative bg-ammo-container-background">
                    <p class="text-white">{props?.name}</p>
                    <Show when={!isWeaponMelee()} keyed>
                        <div className="flex gap-2 items-center">
                            <AmmoIcon/>
                            <div class="flex gap-2">
                                <p className="text-orange-600">{props?.currentAmmo}</p>
                                <p className="text-gray-600">{props?.maxAmmo}</p>
                            </div>
                        </div>
                    </Show>
                </div>
            </div>
        </Show>
    )
}

export const InfoHud = (props) => {

    const hudStorageState = useHudStorageState();
    const settingsStorageState = useSettingsStorageState();
    const settings = () => settingsStorageState.settings
    const defaultConfigs = () => settingsStorageState.defaultConfigs
    const hud = () => hudStorageState.hud
    const moneys = () => hud().moneys
    const weapon = () => hud().weaponData
    const job = () => hud().job
    const serverLogo = () => defaultConfigs().ServerLogo

    return (
        <div className="flex flex-col gap-2 w-48 absolute right-0 top-6">
            <FirstRow hide={settings().Info} playerId={hud().playerId} onlinePlayers={hud().onlinePlayers} serverLogo={serverLogo()}/>
            <SecondRow hide={settings().Money} bank={hudStorageState.hud.moneys.bank} money={moneys().money} jobLabel={job()} />
            <ThirdRow hide={settings().Weapon} use={hud().weaponData?.use} name={weapon().name} image={weapon().image} currentAmmo={weapon().currentAmmo} isWeaponMelee={weapon().isWeaponMelee} maxAmmo={weapon().maxAmmo}/>
        </div>
    );
};