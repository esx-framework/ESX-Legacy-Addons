import TranslateData from "../assets/translate.json";

/**
 * Converts the key into dynamic language text
 * @param translateKey current translated string
 * @param translateObjectName current translate object name (Status,Speedo,Settings)
 * @param defaultKey (optional) return default string if doesn't exist key
 * @return {*}
 */
let lang = "en";
export const translate = (
  translateKey,
  translateObjectName = "General",
  defaultKey = null,
) => {
  if (!TranslateData[lang][translateObjectName][translateKey.toLowerCase()]) {
    console.warn(
      `Doesn't exist translate key: ${translateKey.toLowerCase()} in ${translateObjectName} translate object`,
    );
    return defaultKey ? defaultKey : translateKey;
  }
  return TranslateData[lang][translateObjectName][translateKey.toLowerCase()];
};

export function setLang(currentLang) {
  let newLang = currentLang.length > 0 ? currentLang : "en";
  if (!TranslateData[currentLang]) {
    console.warn(
      `There is no such language type!  Current language type: ${currentLang} If you want add other lang you can do here: web/src/assets/translate.json !!IMPORTANT this file only see with the unbuilt version.`,
    );
    newLang = "en";
  }
  lang = newLang;
}
