import './Speedo.css'
import {createEffect, createSignal, onCleanup, Show} from "solid-js";

import Sound from '../IndicatorSound.mp3'
import SeatbeltAlert from '../SeatbeltAlertSound.mp3';
import SeatbeltOff from '../SeatbeltOffSound.mp3';
import SeatbeltOn from '../SeatbeltOnSound.mp3';
import {useHudStorageState} from "../Contexts/HudStorage";
import {useSettingsStorageState} from "../Contexts/SettingsStorage";

const VehType = {
    AIR:"AIR",
    LAND:"LAND",
    MOTO: "MOTO",
}

const defaultObject = {
    maxVal: 300 /**Max value of the meter*/,
    divFact: 6 /**Division value of the meter*/,
    dangerLevel: 150 /**more than this leval, color will be red*/,
    initDeg: -45 /**reading begins angle*/,
    maxDeg: 270 /**total angle of the meter reading*/,
    edgeRadius: 150 /**radius of the meter circle*/,
    indicatorRadius: 125 /**radius of indicators position*/,
    indicatorNumbRadius: 90 /**radius of numbers position*/,
    nobW: 25 /**indicator nob width*/,
    nobH: 4 /**indicator nob height*/,
    numbW: 30 /**indicator number width*/,
    numbH: 30 /**indicator number height*/,
    midNobW: 5 /**indicator mid nob width*/,
    midNobH: 3 /**indicator mid nob height*/,
    noOfSmallDiv: 5 /**no of small div between main div*/,
}

/*SVGS*/
const VehicleSpeedIndicator = (props) => <svg style="position: absolute;top: 50%;left: 50%;transform: translate(-58%, -65%);" className="absolute left-0" width="385" height="450" viewBox="0 0 350 280" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path
        fill="transparent"
        class="circleBackground"
        stroke="red"
        stroke-width="15"
        d="  M 114 292 A 126 126 0 1 1 288 291"
    ></path>

    <path
        fill="transparent"
        class="circleProgress ease-in duration-100"
        stroke="red"
        stroke-width="15"
        d="  M 114 292 A 126 126 0 1 1 288 291"
        stroke-dasharray={props?.speed}
    ></path>

    {/*<path*/}
    {/*    fill="transparent"*/}
    {/*    class="circleDashed"*/}
    {/*    stroke="red"*/}
    {/*    stroke-width="15"*/}
    {/*    d=" M 114 292 A 126 126 0 1 1 288 291"*/}
    {/*    stroke-dasharray="18.56, 10"*/}
    {/*></path>*/}
</svg>
const VehicleDamageIndicator = (props) => <svg style="position: absolute;top: 50%;left: 50%;transform: translate(-64%, -66%) rotate(0deg);" className="absolute left-0" width="365" height="450" viewBox="0 0 310 280" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path
        class="backgroundPartCircle"
        d=" M 87 282 A 140 140 0 0 1 79 130"
        fill="transparent"
    />
    <path
        class="progressPartCircle ease-in duration-300"
        d=" M 87 282 A 140 140 0 0 1 79 130"
        fill="transparent"
        stroke-dasharray={props?.damage}
    />
    {/*<path*/}
    {/*    class="dashesPartCircle"*/}
    {/*    d=" M 87 282 A 140 140 0 0 1 79 130"*/}
    {/*    fill="transparent"*/}
    {/*/>*/}
</svg>

/*ICONS*/
const FuelIcon = () => <svg width="10" height="12" viewBox="0 0 10 12" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path id="fuelIcon" d="M9.92673 1.57324L8.92673 0.573233C8.82907 0.475569 8.67086 0.475569 8.57322 0.573233C8.47556 0.670896 8.47556 0.829099 8.57322 0.926739L9.39646 1.74998L8.57322 2.57322C8.52635 2.62009 8.49998 2.68356 8.49998 2.74998V3.49998C8.49998 4.05151 8.94848 4.49999 9.49998 4.49999V8.74996C9.49998 8.88789 9.38793 8.99997 9.24998 8.99997C9.11205 8.99997 8.99997 8.88792 8.99997 8.74996V8.24997C8.99997 7.8364 8.66355 7.49998 8.24997 7.49998H7.99999V1C7.99999 0.448475 7.55152 0 6.99999 0H2.00001C1.4485 0 1 0.448475 1 1V9.99998C0.448499 9.99998 0 10.4485 0 11V11.75C0 11.8882 0.11182 12 0.250007 12H8.74999C8.88817 12 8.99999 11.8882 8.99999 11.75V11C8.99999 10.4485 8.55152 9.99998 7.99999 9.99998V7.99999H8.25C8.38793 7.99999 8.5 8.11204 8.5 8.25V8.74999C8.5 9.16356 8.83643 9.49998 9.25 9.49998C9.66358 9.49998 10 9.16356 10 8.74999V1.75C9.99998 1.68358 9.97361 1.62011 9.92673 1.57324ZM6.99999 4.25462C6.99999 4.39281 6.88817 4.50463 6.74998 4.50463H2.24999C2.11181 4.50463 1.99999 4.39281 1.99999 4.25462V1.24999C1.99999 1.1118 2.11181 0.999981 2.24999 0.999981H6.74998C6.88817 0.999981 6.99999 1.1118 6.99999 1.24999V4.25462Z"/>
</svg>
const ArrowsIcon = (props) =>{

    const leftIndex = () => props.state.leftIndex && props.onIndex()
    const rightIndex = () => props.state.rightIndex && props.onIndex()

    return(
        <div class="mt-4 flex gap-4 items-center justify-center">
            <div>
                <LeftArrowIcon state={leftIndex}/>
            </div>
            <div><p class="textColor unitTextColor">{props?.kmh ? 'km/h' : 'mph'}</p></div>
            <div>
                <RightArrowIcon state={rightIndex}/>
            </div>
        </div>
    )
}

const LeftArrowIcon = (props) => <svg width="19" height="20" viewBox="0 0 19 20" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path class={` ${props?.state()  ?  "blinkerOn" : "" } blink indexColor`} d="M5.40816 10.5135L9.25672 4.48904C9.31624 4.39661 9.24289 4.27522 9.13217 4.28584L7.85473 4.40834C7.77375 4.4161 7.69973 4.46156 7.65617 4.52911L3.95407 10.3244C3.88993 10.4245 3.86124 10.5432 3.87259 10.6616C3.88393 10.7799 3.93467 10.8911 4.01666 10.9772L8.75246 15.9616C8.80821 16.0213 8.88937 16.0502 8.97035 16.0425L10.2478 15.92C10.3585 15.9094 10.4075 15.7762 10.3315 15.6968L5.40816 10.5135ZM10.432 10.0318L14.2806 4.0073C14.3401 3.91487 14.2667 3.79348 14.156 3.8041L12.8786 3.92659C12.7976 3.93436 12.7236 3.97982 12.68 4.04737L8.9779 9.84264C8.91376 9.94275 8.88507 10.0615 8.89641 10.1798C8.90776 10.2982 8.9585 10.4093 9.04049 10.4954L13.7763 15.4799C13.832 15.5396 13.9132 15.5685 13.9942 15.5607L15.2716 15.4382C15.3823 15.4276 15.4313 15.2945 15.3553 15.2151L10.432 10.0318Z" fill-opacity="0.3"/>
</svg>
const RightArrowIcon = (props) => <svg width="19" height="20" viewBox="0 0 19 20" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path class={` ${props?.state()  ?  "blinkerOn" : "" } blink indexColor`} d="M13.397 10.6515L8.41209 15.7755C8.33515 15.8541 8.38249 15.9877 8.49308 15.9997L9.76897 16.1375C9.84984 16.1462 9.93152 16.1166 9.98781 16.0592L14.7831 11.1301C14.8661 11.045 14.9181 10.9345 14.9309 10.8163C14.9437 10.6981 14.9164 10.579 14.8535 10.4781L11.2207 4.64064C11.1782 4.57092 11.1045 4.52623 11.0236 4.5175L9.74776 4.37973C9.63718 4.36779 9.56238 4.48829 9.62079 4.58143L13.397 10.6515ZM8.37932 10.1097L3.39438 15.2337C3.31744 15.3123 3.36479 15.446 3.47537 15.4579L4.75126 15.5957C4.83214 15.6044 4.91381 15.5748 4.9701 15.5174L9.76534 10.5883C9.84836 10.5032 9.90042 10.3927 9.91319 10.2745C9.92595 10.1563 9.89868 10.0372 9.83574 9.93633L6.20304 4.09884C6.16047 4.02912 6.08682 3.98444 6.00594 3.9757L4.73005 3.83794C4.61947 3.826 4.54467 3.9465 4.60308 4.03963L8.37932 10.1097Z" fill-opacity="0.3"/>
</svg>
const VehicleDamageStatusIcon = () => <svg class="absolute bottom-[9%] left-[5%]" width="22" height="22" viewBox="0 0 22 22" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g clip-path="url(#clip0_22_147)">
        <path class="damageStatusIcon"  d="M10.2982 13.8847L15.5482 19.1346L17.3944 17.2446L12.1444 11.9946L10.2982 13.8847ZM13.5532 9.33465C13.2119 9.33465 12.8444 9.2909 12.5557 9.1684L2.58941 19.0909L0.743164 17.2446L7.22691 10.7696L5.67816 9.21215L5.04816 9.82465L3.77941 8.5909V11.0934L3.16691 11.7059L0.0869141 8.5909L0.699414 7.9784H3.15816L1.93316 6.74465L5.04816 3.62965C5.29015 3.38636 5.57783 3.1933 5.89467 3.06156C6.21152 2.92982 6.55127 2.862 6.89441 2.862C7.23756 2.862 7.57731 2.92982 7.89416 3.06156C8.211 3.1933 8.49868 3.38636 8.74066 3.62965L6.89441 5.51965L8.12816 6.74465L7.50691 7.3659L9.07316 8.9234L10.6657 7.2784C10.5432 6.98965 10.4907 6.62215 10.4907 6.2984C10.4872 5.89444 10.5639 5.4938 10.7164 5.11969C10.8688 4.74558 11.094 4.40544 11.3788 4.11897C11.6637 3.8325 12.0025 3.6054 12.3758 3.45081C12.749 3.29622 13.1492 3.21723 13.5532 3.2184C14.0694 3.2184 14.5244 3.3409 14.9357 3.5859L12.5994 5.92215L13.9119 7.23465L16.2482 4.8984C16.4932 5.30965 16.6157 5.74715 16.6157 6.2984C16.6157 7.9784 15.2594 9.33465 13.5532 9.33465Z"/>
    </g>
    <defs>
        <clipPath id="clip0_22_147">
            <rect class="damageStatusIcon" width="21" height="21" transform="translate(0.0869141 0.862)"/>
        </clipPath>
    </defs>
</svg>

/*MORE INDICATORS ICON*/
const TempomatIcon = (props) => <svg class="absolute bottom-[21px] left-[111px]" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path class="tempomatIcon" d="M20.39 8.56001L19.15 10.42C19.7432 11.6031 20.0336 12.9148 19.9952 14.2377C19.9568 15.5606 19.5908 16.8533 18.93 18H5.06999C4.21115 16.5101 3.85528 14.7831 4.05513 13.0751C4.25497 11.367 4.9999 9.76884 6.17946 8.51744C7.35903 7.26604 8.91045 6.42805 10.6037 6.12771C12.297 5.82736 14.042 6.08064 15.58 6.85001L17.44 5.61001C15.4695 4.33293 13.1125 3.78997 10.7819 4.07628C8.45132 4.36259 6.2958 5.45991 4.69304 7.17595C3.09028 8.892 2.14252 11.1173 2.0158 13.462C1.88909 15.8067 2.59151 18.1212 3.99999 20H20C21.2266 18.3613 21.9207 16.3856 21.9887 14.3398C22.0566 12.2939 21.4951 10.2765 20.38 8.56001H20.39Z" fill-opacity={props?.state ? '1' : '0.5'}/>
    <path class="tempomatIcon" d="M10.59 15.41C10.7757 15.5959 10.9963 15.7435 11.2391 15.8441C11.4819 15.9448 11.7422 15.9966 12.005 15.9966C12.2678 15.9966 12.5281 15.9448 12.7709 15.8441C13.0137 15.7435 13.2342 15.5959 13.42 15.41L19.08 6.91998L10.59 12.58C10.404 12.7657 10.2565 12.9863 10.1559 13.2291C10.0552 13.4719 10.0034 13.7322 10.0034 13.995C10.0034 14.2578 10.0552 14.5181 10.1559 14.7609C10.2565 15.0037 10.404 15.2242 10.59 15.41Z" fill-opacity={props?.state ? '1' : '0.5'}/>
</svg>
const DoorIcon = (props) =><svg class="absolute right-[73px] bottom-[37px]"  width="25" height="25" viewBox="0 0 25 25" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path class="doorIcon" d="M19.0869 14.862H16.0869V16.862H19.0869V14.862ZM22.0869 21.862H3.08691V11.862L11.0869 3.862H21.0869C21.3521 3.862 21.6065 3.96736 21.794 4.15489C21.9816 4.34243 22.0869 4.59678 22.0869 4.862V21.862ZM11.9169 5.862L5.91691 11.862H20.0869V5.862H11.9169Z" fill-opacity={props?.state ? '1' : '0.5'}/>
</svg>
const LightIcon = (props) => <svg class={`absolute ${props?.vehType ? 'right-[111px] bottom-[21px]' :'right-[138px] bottom-[22px]'}`}  width="25" height="25" viewBox="0 0 25 25" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path class="lightIcon" d="M10.0869 22.862H14.0869H10.0869ZM5.08692 9.862C5.08692 8.00548 5.82441 6.22501 7.13717 4.91225C8.44992 3.5995 10.2304 2.862 12.0869 2.862C13.9434 2.862 15.7239 3.5995 17.0367 4.91225C18.3494 6.22501 19.0869 8.00548 19.0869 9.862C19.0876 10.9891 18.815 12.0995 18.2925 13.0982C17.77 14.0968 17.0132 14.9539 16.0869 15.596L15.5449 18.162C15.4732 18.635 15.2342 19.0666 14.8715 19.3785C14.5088 19.6904 14.0463 19.8619 13.5679 19.862H10.6059C10.1275 19.8619 9.66503 19.6904 9.30231 19.3785C8.93958 19.0666 8.70067 18.635 8.62892 18.162L8.08692 15.607C7.16032 14.9626 6.40349 14.1035 5.88107 13.1031C5.35865 12.1027 5.08617 10.9906 5.08692 9.862V9.862Z" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" stroke-opacity={props?.state ? '1' : '0.5'}/>
    <path class="lightIcon"  d="M8.08691 15.862H16.0869" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" stroke-opacity={props?.state ? '1' : '0.5'}/>
</svg>
const EngineIcon = (props) =><svg class="absolute left-[67px] bottom-[34px]"  width="25" height="25" viewBox="0 0 25 25" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path class="engineIcon" d="M7.08691 4.862V6.862H10.0869V8.862H7.08691L5.08691 10.862V13.862H3.08691V10.862H1.08691V18.862H3.08691V15.862H5.08691V18.862H8.08691L10.0869 20.862H18.0869V16.862H20.0869V19.862H23.0869V9.862H20.0869V12.862H18.0869V8.862H12.0869V6.862H15.0869V4.862H7.08691Z" fill-opacity={props?.state ? '1' : '0.5'}/>
</svg>
const SeatbeltIcon = (props) => <svg width="45" height="45" viewBox="0 0 13 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path class={` ${props?.state() ?  "blinkerOn" : "" } blink seatbeltIconColor`} d="M6.4623 0C6.86228 0 7.24587 0.158891 7.5287 0.441718C7.81153 0.724546 7.97042 1.10814 7.97042 1.50812C7.97042 2.34513 7.2993 3.01624 6.4623 3.01624C6.06232 3.01624 5.67872 2.85735 5.39589 2.57452C5.11307 2.2917 4.95418 1.9081 4.95418 1.50812C4.95418 1.10814 5.11307 0.724546 5.39589 0.441718C5.67872 0.158891 6.06232 0 6.4623 0ZM6.75638 9.64443C7.82752 9.64026 8.89787 9.70322 9.96114 9.83295C10.0064 7.7819 9.82541 5.97216 9.47854 5.27842C9.38051 5.07483 9.24478 4.90139 9.10151 4.75058L3.01624 9.96868C4.04176 9.80278 5.33121 9.64443 6.75638 9.64443ZM3.03886 11.3109C3.13689 12.623 3.33295 13.9501 3.64965 15.0812H5.21056C4.99188 14.4176 4.83353 13.641 4.71288 12.819C4.71288 12.819 6.4623 12.4872 8.21172 12.819C8.09107 13.641 7.93271 14.4176 7.71404 15.0812H9.27494C9.60673 13.9124 9.80278 12.5249 9.90081 11.1526C8.85742 11.0264 7.80737 10.9635 6.75638 10.964C5.30104 10.964 4.03422 11.1224 3.03886 11.3109ZM6.4623 3.7703C6.4623 3.7703 4.20012 3.7703 3.44606 5.27842C3.18967 5.79118 3.02378 6.89965 2.971 8.2645L7.91009 4.02668C7.16357 3.7703 6.4623 3.7703 6.4623 3.7703ZM11.4165 2.7674L10.5568 1.7645L7.91009 4.03422C8.32483 4.17749 8.76218 4.40371 9.10151 4.75058L11.4165 2.7674ZM13 10.4287C12.9321 10.406 11.8463 10.0516 9.96114 9.83295C9.9536 10.2628 9.93097 10.7077 9.90081 11.1526C11.5974 11.3637 12.5702 11.6879 12.5853 11.6879L13 10.4287ZM2.971 8.2645L0 10.8132L0.671114 11.9292C0.686195 11.9217 1.5609 11.5824 3.03886 11.3109C2.95592 10.2477 2.93329 9.19954 2.971 8.2645Z" fill-opacity="0.3"/>
    </svg>


export const Speedo = (props) =>{

    const hudStorageState = useHudStorageState();
    const settingsStorageState = useSettingsStorageState();
    const settings = () => settingsStorageState.settings
    const defaultConfigs = () => settingsStorageState.defaultConfigs
    const [checkSound, setCheckSound] = createSignal(false)
    const [onIndex,setOnIndex] = createSignal(false)
    const [seatbeltState, setSeatbeltState] = createSignal(false)
    const speedo = () => hudStorageState.speedo
    const indicators = () => speedo().defaultIndicators
    const damage = () => speedo().damageLevel
    const vehType = () => speedo().vehType
    const isKmh = () => defaultConfigs().Kmh
    const speed = () => speedo().speed
    const show = () => speedo().show
    const fuel = () => speedo().fuel
    const mileage = () => speedo().mileage
    const isDriver = () => speedo().driver
    const rpm = () => speedo().rpm

    let rows = []
    const createTemplate = () =>{
        defaultObject.maxVal = isKmh() ? 300 : 200
        defaultObject.divFact = isKmh() ? 6 : 4
        defaultObject.dangerLevel = isKmh() ? 180 : 120

        if(vehType() === VehType.AIR){
            defaultObject.maxVal = 2500
            defaultObject.divFact = 50
            defaultObject.dangerLevel = 1500
        }


        if(!props?.template){
            const speedoContainer = document.getElementById('speedoContainer');
            if(speedoContainer){
                speedoContainer.innerHTML = ""
            }
        }


        const noOfDev = defaultObject.maxVal/ defaultObject.divFact
        const divDeg = defaultObject.maxDeg/noOfDev
        let induCatorLinesPosLeft ,induCatorLinesPosTop,tempDiv,induCatorNumbPosLeft,induCatorNumbPosTop = ''

        if(!settings().Needle && vehType() !== VehType.AIR){
            rows.push(<div class="speedNobe">
                <div></div>
            </div>)
        }

        let tempDegInd
        for(let i = 0; i <= noOfDev; i++){

            const curDig = defaultObject.initDeg + i * divDeg
            let curIndVal = i * defaultObject.divFact;

            let dangCls = "";
            if (curIndVal >= defaultObject.dangerLevel) {
                dangCls = "danger";
            }

            let induCatorLinesPosY =
                defaultObject.indicatorRadius * Math.cos(0.01746 * curDig);
            let induCatorLinesPosX =
                defaultObject.indicatorRadius * Math.sin(0.01746 * curDig);

            let induCatorNumbPosY =
                defaultObject.indicatorNumbRadius * Math.cos(0.01746 * curDig);
            let induCatorNumbPosX =
                defaultObject.indicatorNumbRadius * Math.sin(0.01746 * curDig);

            if (i % defaultObject.noOfSmallDiv === 0) {
                induCatorLinesPosLeft =
                    defaultObject.edgeRadius - induCatorLinesPosX - 2;
                induCatorLinesPosTop =
                    defaultObject.edgeRadius - induCatorLinesPosY - 10;

                tempDegInd = `transform: rotate(${curDig}deg)`



                induCatorNumbPosLeft =
                    defaultObject.edgeRadius -
                    induCatorNumbPosX -
                    defaultObject.numbW / 2;
                induCatorNumbPosTop =
                    defaultObject.edgeRadius -
                    induCatorNumbPosY -
                    defaultObject.numbH / 2;

                rows.push(
                    <>
                        <div class={`nob ${dangCls}`} style={`left: ${induCatorLinesPosTop}px; top: ${induCatorLinesPosLeft}px; ${tempDegInd}`}>

                        </div>
                        <div class={`numb ${dangCls}`} style={`left: ${induCatorNumbPosTop}px; top: ${induCatorNumbPosLeft}px;`}>
                            {curIndVal}
                        </div>
                    </>
                )

            }
            else{

                induCatorLinesPosLeft =
                    defaultObject.edgeRadius -
                    induCatorLinesPosX -
                    defaultObject.midNobH / 2;
                induCatorLinesPosTop =
                    defaultObject.edgeRadius -
                    induCatorLinesPosY -
                    defaultObject.midNobW / 2;

              tempDegInd = `transform: rotate(${curDig}deg)`


                rows.push(
                    <>
                        <div class={`nob midNob ${dangCls}`} style={`left: ${induCatorLinesPosTop}px; top: ${induCatorLinesPosLeft}px; ${tempDegInd}`}>

                        </div>
                    </>
                )
            }
        }

        return rows
    }

    const IndicatorSound = new Audio(Sound);
    const SeatbeltAlertSound = new Audio(SeatbeltAlert)
    const SeatbeltOnSound = new Audio(SeatbeltOn)
    const SeatbeltOffSound = new Audio(SeatbeltOff)
    SeatbeltOnSound.volume = 0.5
    SeatbeltOffSound.volume = 0.5
    SeatbeltAlertSound.volume = 0.2
    IndicatorSound.volume = 0.2
    const indexTimer = setInterval(()=>{
        if((indicators().leftIndex || indicators().rightIndex)){
            if(!settings().IndicatorSound && show()){
                if(!props?.template){
                    IndicatorSound.play();
                }
            }
            setOnIndex(onIndex => !onIndex)
        }
        if(!indicators().seatbelt && vehType() !== VehType.MOTO){
            if(!settings().IndicatorSeatbeltSound && show()){
                if(!props?.template && !checkSound()){
                    SeatbeltAlertSound.play();
                }
            }
            setSeatbeltState(seatbeltState => !seatbeltState)
        }
    },500)
    onCleanup(() => clearInterval(indexTimer));

    createEffect(()=>{
        const allElements = document.getElementsByClassName('nob')
        const elements = document.querySelectorAll('#speedoContainer .nob');
        const elementsTemplate = document.querySelectorAll('#templateSpeedoContainer .nob');
        const currentSpeed = VehType.AIR !== vehType() ? speed() : rpm()

        if(!settings().IndicatorSeatbeltSound){
            if(indicators().seatbelt && !checkSound()){
                if(!checkSound()){
                    SeatbeltOnSound.play();
                    setCheckSound(true)
                }
            }

            if(checkSound() && !indicators().seatbelt){
                SeatbeltOffSound.play();
                setCheckSound(false)
            }
        }

        if(!settings().Needle){
            const speedNoble = document.querySelectorAll('#speedoContainer .speedNobe')
            if(speedNoble.length > 0){
                const speedInDeg = (266/defaultObject.maxVal) * currentSpeed + defaultObject.initDeg;
                speedNoble[0].style.transform = `translate(-50%, -50%) rotate(${speedInDeg}deg)`
            }
        }

        allElements.forEach((element)=>{
            element.classList.remove("bright");
            element.classList.remove("brightDanger")
        })

        for(let i = 0; i < elements.length; i++){
            const calcDeg = i * defaultObject.divFact
            if(currentSpeed < calcDeg){
                break
            }
            if(calcDeg >= defaultObject.dangerLevel){
                elements[i].classList.add("brightDanger");
                if(elementsTemplate.length > 0)
                elementsTemplate[i].classList.add("brightDanger");
            }
            else{
                elements[i].classList.add("bright");
                if(elementsTemplate.length > 0)
                elementsTemplate[i].classList.add("bright")
            }
        }
    })

    /* HUD COMPONENTS */
    const VehicleHud = () =>{
        return(
            <>
                <VehicleSpeedIndicator speed={speedo().speedInDeg}/>
                <VehicleDamageIndicator damage={damage()}/>
                <VehicleDamageStatusIcon/>
                <TempomatIcon state={indicators()?.tempomat}/>
                <DoorIcon state={indicators()?.door}/>
                <LightIcon state={indicators()?.light} vehType={vehType() !== VehType.AIR}/>
                <EngineIcon state={indicators()?.engine}/>
                <Show when={!settings().Needle} keyed>
                    <div class="speedoNoobleContainer absolute z-10 rounded-full w-10 h-10 top-1/2 left-1/2 -translate-x-1/2 -translate-y-[70%]"></div>
                </Show>
                <Show when={settings().Needle} keyed>
                        <h2 class="text-5xl z-20 absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 textColor currentSpeedTextColor">{speed()}</h2>
                </Show>
                <div class="absolute w-[30%] top-1/2 left-1/2 -translate-x-1/2 translate-y-[15%]">
                    <div class="flex flex-col">
                            <ArrowsIcon state={indicators()} onIndex={onIndex} kmh={isKmh()}/>
                            <div>
                                <Show when={props?.template || isDriver()} keyed>
                                    <span class="textColor mileageTextColor">{mileage()}{isKmh() ? 'km' : 'mi'}</span>
                                </Show>
                            </div>
                        <div class="flex flex-col items-center justify-center">
                            <div class="textColor fuelTextColor">{fuel().level}/{fuel().maxLevel}</div>
                            <div>
                                <FuelIcon/>
                            </div>
                        </div>
                    </div>
                </div>
            </>
        )
    }
    const AirHud = () =>{
        return(
            <>
                <VehicleDamageIndicator damage={damage()}/>
                <VehicleDamageStatusIcon/>
                <DoorIcon state={indicators()?.door}/>
                <LightIcon state={indicators()?.light} vehType={vehType() !== VehType.AIR}/>
                <EngineIcon state={indicators()?.engine}/>
                <h2 class="text-5xl absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-[70%] textColor currentSpeedTextColor">{speed()}</h2>
                <div class="absolute w-[30%] top-1/2 left-1/2 -translate-x-1/2 translate-y-[15%]">
                    <div class="flex flex-col">
                        <div class="flex flex-col mt-2 items-center justify-center">
                            <div class="textColor fuelTextColor">{fuel().level}/{fuel().maxLevel}</div>
                            <div>
                                <FuelIcon/>
                            </div>
                        </div>
                    </div>
                </div>
            </>
        )
    }

    return(
        <div class={`${props?.template ? 'template-main-container' : 'speedo main-container'} ${!show() && !props?.template ? 'slideOut' : ''}`}>

            <Show when={!indicators().seatbelt && vehType() !== VehType.MOTO} keyed>
                <div class="w-10 h-10 absolute top-[26%] -left-[25%]">
                    <SeatbeltIcon state={seatbeltState}/>
                </div>
            </Show>

            <div class="main-container2"></div>

            <Show when={vehType() === VehType.AIR} keyed>
                <AirHud/>
            </Show>

            <Show when={vehType() !== VehType.AIR} keyed>
                <VehicleHud/>
            </Show>

            <div class="w-[300px] h-[300px]" id={props?.template ? 'templateSpeedoContainer': 'speedoContainer'}>
                {createTemplate()}
            </div>
        </div>
    )
}



