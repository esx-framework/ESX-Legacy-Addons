import type { ComponentChild } from "preact"

import Logo from '../assets/logo.png';
import LightEllipse from "./LightEllipse";

export default function PageWrapper({ children }: { children: ComponentChild }) {
	return <>
		<div className={'fixed top-[60px] left-[60px] z-10'}>
			<img src={Logo} alt="Logo" className="w-[127px] h-full" />
		</div>

		<div className={'fixed top-[60px] right-[60px] z-10'}>
			<button className={'bg-[rgba(255,0,0,0.4)] w-[48px] h-[48px] border border-[rgb(255,0,0,1)] rounded-[10px] flex items-center justify-center focus:outline-none hover:bg-[rgba(255,0,0,0.6)] transition-all duration-200 ease-out active:scale-[0.95]'}>
				<svg width="33" height="33" viewBox="0 0 33 33" fill="none" xmlns="http://www.w3.org/2000/svg">
					<path d="M16.3636 18.2729L9.6818 24.9548C9.4318 25.2048 9.11361 25.3298 8.72725 25.3298C8.34089 25.3298 8.0227 25.2048 7.7727 24.9548C7.5227 24.7048 7.39771 24.3866 7.39771 24.0002C7.39771 23.6139 7.5227 23.2957 7.7727 23.0457L14.4545 16.3639L7.7727 9.68204C7.5227 9.43204 7.39771 9.11386 7.39771 8.72749C7.39771 8.34113 7.5227 8.02295 7.7727 7.77295C8.0227 7.52295 8.34089 7.39795 8.72725 7.39795C9.11361 7.39795 9.4318 7.52295 9.6818 7.77295L16.3636 14.4548L23.0454 7.77295C23.2954 7.52295 23.6136 7.39795 24 7.39795C24.3863 7.39795 24.7045 7.52295 24.9545 7.77295C25.2045 8.02295 25.3295 8.34113 25.3295 8.72749C25.3295 9.11386 25.2045 9.43204 24.9545 9.68204L18.2727 16.3639L24.9545 23.0457C25.2045 23.2957 25.3295 23.6139 25.3295 24.0002C25.3295 24.3866 25.2045 24.7048 24.9545 24.9548C24.7045 25.2048 24.3863 25.3298 24 25.3298C23.6136 25.3298 23.2954 25.2048 23.0454 24.9548L16.3636 18.2729Z" fill="#F2F2F2" />
				</svg>
			</button>
		</div>

		{children}

		<div className="absolute -z-10 bottom-[-40vh] right-[-23vw]" style={{ width: '50vw', height: '80vh' }}>
			<LightEllipse id="white-ellipse" color={'rgb(242,242,242)'} opacity={0.2} />
		</div>
		<div className="absolute -z-10 bottom-[-40vh] left-[-23vw]" style={{ width: '50vw', height: '80vh' }}>
			<LightEllipse id="orange-ellipse" color={'rgb(251,155,4)'} opacity={0.2} />
		</div>
	</>
}
