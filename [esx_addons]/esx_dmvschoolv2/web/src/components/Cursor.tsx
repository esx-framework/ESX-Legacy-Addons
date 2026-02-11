import { useState, useEffect } from 'preact/hooks';

interface CursorProps {
	color?: string;
	size?: number;
}

export function Cursor({ color = '#fb9b04', size = 16 }: CursorProps) {
	const [cursorPos, setCursorPos] = useState({ x: 0, y: 0 });
	const [isClicking, setIsClicking] = useState(false);

	useEffect(() => {
		const handleMouseMove = (e: MouseEvent) => {
			setCursorPos({ x: e.clientX, y: e.clientY });
		};

		const handleMouseDown = () => setIsClicking(true);
		const handleMouseUp = () => setIsClicking(false);

		window.addEventListener('mousemove', handleMouseMove);
		window.addEventListener('mousedown', handleMouseDown);
		window.addEventListener('mouseup', handleMouseUp);

		return () => {
			window.removeEventListener('mousemove', handleMouseMove);
			window.removeEventListener('mousedown', handleMouseDown);
			window.removeEventListener('mouseup', handleMouseUp);
		};
	}, []);

	return (
		<>
			{/* Outer ring */}
			<div
				className="fixed pointer-events-none z-[9999] rounded-full border-2 transition-transform duration-150 ease-out"
				style={{
					left: `${cursorPos.x}px`,
					top: `${cursorPos.y}px`,
					width: `${size * 2}px`,
					height: `${size * 2}px`,
					marginLeft: `${-size}px`,
					marginTop: `${-size}px`,
					borderColor: color,
					transform: `scale(${isClicking ? 0.8 : 1})`,
					boxShadow: `0 0 20px ${color}40`,
				}}
			/>

			{/* Inner dot */}
			<div
				className="fixed pointer-events-none z-[10000] rounded-full transition-transform duration-150 ease-out"
				style={{
					left: `${cursorPos.x}px`,
					top: `${cursorPos.y}px`,
					width: `${size / 2}px`,
					height: `${size / 2}px`,
					marginLeft: `${-size / 4}px`,
					marginTop: `${-size / 4}px`,
					backgroundColor: color,
					transform: `scale(${isClicking ? 1.5 : 1})`,
					boxShadow: `0 0 10px ${color}`,
				}}
			/>
		</>
	);
}
