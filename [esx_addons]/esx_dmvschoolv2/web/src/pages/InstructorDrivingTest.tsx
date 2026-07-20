import InGameExample from "../assets/ingameexample.png"
import MapExample from "../assets/mapexample.png"
import { useConfig } from "../context/ConfigContext"
import { useState, useEffect } from "preact/hooks"
import { formatTime } from "../utils/formatTime"

export default function InstructorDrivingTest() {
    const { config } = useConfig();
    const [elapsedTime, setElapsedTime] = useState(0);
    const [timerRunning, setTimerRunning] = useState(false);

    useEffect(() => {
        const handleMessage = (event: MessageEvent) => {
            const { action } = event.data;
            if (action === 'startTimer') {
                setElapsedTime(0);
                setTimerRunning(true);
            } else if (action === 'stopTimer') {
                setTimerRunning(false);
            }
        };

        window.addEventListener('message', handleMessage);
        return () => window.removeEventListener('message', handleMessage);
    }, []);

    useEffect(() => {
        let interval: ReturnType<typeof setInterval>;
        if (timerRunning) {
            interval = setInterval(() => {
                setElapsedTime((prev) => prev + 1);
            }, 1000);
        }
        return () => clearInterval(interval);
    }, [timerRunning]);

	console.log("Config:", config);

    if (!config?.instructorDrivingTest) return null;

	console.log("Instructor Driving Test Config:", config.instructorDrivingTest);

    const { progress, speeding, mistakes, maxMistakes, unitSystem } = config.instructorDrivingTest;
    const activePills = Math.round((progress / 100) * 6);

    return (
        <>
            {import.meta.env.DEV && (
                <div className="fixed inset-0 z-0">
                    <img src={InGameExample} alt="Background" className="w-full h-full object-cover" />
                </div>
            )}

            <div className={'bg-[rgb(22,22,22)] p-[30px] text-[15px] font-medium text-[rgba(242,242,242)] rounded-[20px] w-[350px] h-[571px] absolute top-1/2 left-[20px] transform -translate-y-1/2 z-10'}>
                <h1 className={'text-[20px] font-bold mb-[20px]'}>Instructor Driving Test</h1>
                <div>
                    <img src={MapExample} alt="Map Example" className="w-full rounded-[10px]" />
                </div>
                <div className={'mt-[20px]'}>
                    <div className={'flex justify-between items-center'}>
                        <p>Test Progress</p>
                        <p className={'font-semibold text-[rgb(251,155,4)]'} style={{
                            textShadow: '0px 0px 15px 0px rgba(251, 155, 4, 0.25)'
                        }}>{progress}%</p>
                    </div>
                    <div className={'mt-[5px]'}>
                        <div className={'flex items-center'}>
                            <div className="flex w-full gap-[6px]">
                                {[...Array(6)].map((_, i) => (
                                    <div
                                        key={i}
                                        className={`h-[10px] flex-1 rounded-[4px] ${i < activePills ? 'bg-[rgb(251,155,4)]' : 'bg-[rgb(56,56,56)]'}`}
                                        style={i < activePills ? {
                                            boxShadow: '0px 0px 15px 1px rgba(251, 155, 4, 0.25)'
                                        } : {}}
                                    ></div>
                                ))}
                            </div>
                        </div>
                    </div>
                </div>
                <div className={'mt-[20px] flex flex-col gap-[5px]'}>
                    <div className={'bg-[rgb(37,37,37)] w-full h-[40px] rounded-[10px] flex items-center justify-between px-[15px]'}>
                        <p>Speeding:</p>
                        <p className={'font-semibold text-[rgb(251,155,4)]'} style={{
                            textShadow: '0px 0px 15px 0px rgba(251, 155, 4, 0.25)'
                        }}>{speeding} {unitSystem == 'imperial' ? 'MPH' : 'KMH'}</p>
                    </div>
                    <div className={'bg-[rgb(37,37,37)] w-full h-[40px] rounded-[10px] flex items-center justify-between px-[15px]'}>
                        <p>Mistakes:</p>
                        <p className={'font-semibold text-[rgb(251,155,4)]'} style={{
                            textShadow: '0px 0px 15px 0px rgba(251, 155, 4, 0.25)'
                        }}>{mistakes}/{maxMistakes}</p>
                    </div>
                    <div className={'bg-[rgb(37,37,37)] w-full h-[40px] rounded-[10px] flex items-center justify-between px-[15px]'}>
                        <p>Time:</p>
                        <p className={'font-semibold text-[rgb(251,155,4)]'} style={{
                            textShadow: '0px 0px 15px 0px rgba(251, 155, 4, 0.25)'
                        }}>{formatTime(elapsedTime)}</p>
                    </div>
                </div>

                <div className={'mt-[30px] w-full h-[40px] rounded-[10px] flex items-center justify-between font-bold uppercase'}>
                    <div className={'bg-[rgb(251,155,4)] select-none flex items-center text-center h-full rounded-[10px] px-[15px] text-[rgb(37,37,37)]'}>
						<p>Approve License</p>
					</div>
					<div className={'bg-[rgb(255,0,0)] select-none flex items-center text-center h-full rounded-[10px] px-[25px] text-[rgb(242,242,242)] whitespace-nowrap'}>
						<p>Fail Test</p>
					</div>
                </div>
            </div>

        </>
    )
}
