import PageWrapper from "../components/PageWrapper"

export default function LicenseResult({ licensed = false, fullname, age, category, progress = 0 }: { licensed: boolean, fullname?: string, age?: number, category?: string, progress?: number }) {
	return (
		<PageWrapper>
			<h1 className="text-[32px] font-bold uppercase text-white text-center top-[60px] absolute inset-0 flex justify-center">Driving School</h1>

			<div className={'w-full h-full flex items-center justify-center'}>
				<div className={'bg-[rgba(37,37,37,0.25)] p-[50px] w-[733px] h-[498px] rounded-[20px] border border-[rgba(56,56,56,0.5)] backdrop-blur-[5px]'}>
					<div className={'flex flex-col h-full'}>
						<div className="flex-1 flex flex-col justify-center items-center w-full">
							{licensed ? (
								<h1 className={'font-bold text-[32px] text-center uppercase text-[rgba(242,242,242)]'}>You’re now a <span className={'text-[rgba(251,155,4)]'}>licensed driver</span></h1>
							) : (
								<h1 className={'font-bold text-[32px] text-center uppercase text-[rgba(242,242,242)]'}>You’re not yet a <span className={'text-[rgba(251,155,4)]'}>licensed driver</span></h1>
							)}

							<div className={'flex mt-[50px]'}>
								<div className={'w-[200px] h-[200px] mr-[20px]'}>
									<div className="relative flex items-center justify-center w-full h-full">
										<svg width="200" height="200" viewBox="0 0 200 200" className="transform rotate-[-90deg]">
											{progress != 100 && (
												<circle
													cx="100"
													cy="100"
													r="70"
													stroke="rgba(56, 56, 56)"
													stroke-width="30"
													fill="none"
												/>
											)}

											{progress != 0 && (() => {
												const p = progress ?? 0;
												const startAngle = 0;
												const endAngle = p >= 100 ? 359.999 : p * 3.6;
												const innerR = 57;
												const outerR = 83;
												const cx = 100;
												const cy = 100;

												const toRad = (deg: number) => deg * Math.PI / 180;

												const p1 = { x: cx + innerR * Math.cos(toRad(startAngle)), y: cy + innerR * Math.sin(toRad(startAngle)) };
												const p2 = { x: cx + outerR * Math.cos(toRad(startAngle)), y: cy + outerR * Math.sin(toRad(startAngle)) };
												const p3 = { x: cx + outerR * Math.cos(toRad(endAngle)), y: cy + outerR * Math.sin(toRad(endAngle)) };
												const p4 = { x: cx + innerR * Math.cos(toRad(endAngle)), y: cy + innerR * Math.sin(toRad(endAngle)) };

												const largeArc = endAngle - startAngle > 180 ? 1 : 0;

												const d = `
													M ${p1.x} ${p1.y}
													L ${p2.x} ${p2.y}
													A ${outerR} ${outerR} 0 ${largeArc} 1 ${p3.x} ${p3.y}
													L ${p4.x} ${p4.y}
													A ${innerR} ${innerR} 0 ${largeArc} 0 ${p1.x} ${p1.y}
													Z
												`;

												return (
													<path
														d={d}
														fill="currentColor"
														stroke="currentColor"
														strokeWidth="4"
														strokeLinejoin="round"
														style={{ color: licensed ? 'rgb(0, 251, 113)': 'rgb(251,0,0)', filter: licensed ? 'drop-shadow(0px 0px 13px rgba(0, 251, 113, 0.5))':  'drop-shadow(0px 0px 13px rgba(251, 0, 0, 0.5))' }}
													/>
												);
											})()}
										</svg>
										<span className="absolute text-[rgb(242,242,242)] font-bold text-[32px]">{progress}%</span>
									</div>
								</div>
								<div>
									<h1 className={'font-bold text-[32px] uppercase text-[rgba(242,242,242)] w-full'}>Driver’s License {licensed ? <span className={'text-[rgba(0,251,113)]'}>Passed</span> : <span className={'text-[rgba(251,0,0)]'}>Failed</span>}</h1>
									<div className={'space-y-[10px] text-[20px] text-[rgba(242,242,242)] mt-[10px]'}>
										<p>{fullname}</p>
										<p>Age: <span className={'text-[rgb(251,155,4)]'}>{age}</span></p>
										<p>Category: <span className={'text-[rgb(251,155,4)] uppercase'}>{category}</span></p>
									</div>
								</div>
							</div>
						</div>
						<div className={'flex justify-end w-full'}>
							<button className={'rounded-[10px] bg-[rgb(251,155,4)] w-[145px] h-[40px] uppercase text-[rgb(37,37,37)] font-bold text-[15px]'}>
								Continue
							</button>
						</div>
					</div>
				</div>
			</div>
		</PageWrapper>
	)
}
