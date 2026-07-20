import type { ComponentChild } from "preact"
import TabletFrame from "../assets/tabletframe.png"
import TabletIngameExample from "../assets/tabletIngameExample.png"
import LightEllipse from "./LightEllipse"

export default function PageWrapper({ children }: { children: ComponentChild }) {
	return <div className="w-screen h-screen">

		{import.meta.env.DEV && (
			<div className="absolute top-0 left-0 -z-10">
				<img src={TabletIngameExample} alt="Tablet Ingame Example" className="w-screen h-screen" />
			</div>
		)}


		<div className={'absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2'}>
			<div>
				<img src={TabletFrame} alt="Tablet Frame" className="w-[1024px] h-auto" />
			</div>
			<div className={'absolute inset-[40px] overflow-hidden rounded-[30px]'}>
				<div className={'w-full h-full bg-[rgb(22,22,22)] relative'}>
					<div className="absolute bottom-[-40vh] right-[-23vw]" style={{ width: '40vw', height: '80vh' }}>
						<LightEllipse id="white-ellipse" color={'rgb(242,242,242)'} opacity={0.4} />
					</div>
					<div className="absolute bottom-[-40vh] left-[-23vw]" style={{ width: '40vw', height: '80vh' }}>
						<LightEllipse id="orange-ellipse" color={'rgb(251,155,4)'} opacity={0.4} />
					</div>
					<div className="relative z-10 w-full h-full">
						{children}
					</div>
					<div className="absolute bottom-[10px] left-1/2 transform -translate-x-1/2 w-[150px] h-[3px] bg-[#f2f2f2] rounded-full z-20"></div>
				</div>
			</div>
		</div>
	</div>

}
