import { createContext } from 'preact';
import { useContext, useState, useEffect } from 'preact/hooks';
import { mockConfig } from '../utils/mockData';

export interface Config {
    licenses: {
        [key: string]: {
            label: string;
            price: number;
            category: string;
            imageSrc: string;
        };
    };
    questions: {
        question: string;
        options: string[];
        selected: number;
        imageSrc: string | null;
    }[];
    progressdata: {
        lessons: { label: string; completed: boolean }[];
        tests: { label: string; completed: boolean }[];
        progress: number;
    };
    licenseresult: {
        licensed: boolean;
        fullname: string;
        age: number;
        category: string;
        progress: number;
    };
    resourceName: string;
    studentDrivingTest: {
        defaultTime: number;
        maxMistakes: number;
        currentObjective: string;
        progress: number;
        checkpointsLeft: number;
        mistakes: number;
    };
}

interface ConfigContextType {
    config: Config | null;
}

const ConfigContext = createContext<ConfigContextType>({
    config: null,
});

export const useConfig = () => useContext(ConfigContext);

export const ConfigProvider = ({ children }: { children: any }) => {
    const [config, setConfig] = useState<Config | null>(null);

    useEffect(() => {
        // @ts-ignore
        if (import.meta.env.DEV) {
            setConfig(mockConfig as unknown as Config);
        } else {
            const resourceName = window.location.host.replace('cfx-nui-', '');

            fetch(`https://${resourceName}/ready`, {
                method: "POST",
                body: JSON.stringify({}),
            }).then(async (res) => {
                const response = await res.json();
                if (response.config) {
                    setConfig(response.config);
                }
            }).catch((err) => {
                console.error("Failed to fetch NUI ready:", err);
            });
        }

        const handleMessage = (event: MessageEvent) => {
            const { action, data } = event.data;

            if (action === 'setConfig') {
                setConfig(data);
            }
        };

        window.addEventListener('message', handleMessage);
        return () => window.removeEventListener('message', handleMessage);
    }, []);

    return (
        <ConfigContext.Provider value={{ config }}>
            {children}
        </ConfigContext.Provider>
    );
};
