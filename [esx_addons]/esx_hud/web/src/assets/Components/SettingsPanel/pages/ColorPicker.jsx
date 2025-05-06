import {onMount} from "solid-js";
import {useSettingsStorageDispatch, useSettingsStorageState} from "../../../Contexts/SettingsStorage";
import '@simonwep/pickr/dist/themes/classic.min.css';
import '@simonwep/pickr/dist/themes/monolith.min.css';  // 'monolith' theme
import '@simonwep/pickr/dist/themes/nano.min.css';      // 'nano' theme
import Pickr from '@simonwep/pickr/dist/pickr.es5.min';

const ColorPaletteIcon = () => <svg width="20" height="20" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path fill="white"  d="M512 256c0 .9 0 1.8 0 2.7c-.4 36.5-33.6 61.3-70.1 61.3H344c-26.5 0-48 21.5-48 48c0 3.4 .4 6.7 1 9.9c2.1 10.2 6.5 20 10.8 29.9c6.1 13.8 12.1 27.5 12.1 42c0 31.8-21.6 60.7-53.4 62c-3.5 .1-7 .2-10.6 .2C114.6 512 0 397.4 0 256S114.6 0 256 0S512 114.6 512 256zM128 288c0-17.7-14.3-32-32-32s-32 14.3-32 32s14.3 32 32 32s32-14.3 32-32zm0-96c17.7 0 32-14.3 32-32s-14.3-32-32-32s-32 14.3-32 32s14.3 32 32 32zM288 96c0-17.7-14.3-32-32-32s-32 14.3-32 32s14.3 32 32 32s32-14.3 32-32zm96 96c17.7 0 32-14.3 32-32s-14.3-32-32-32s-32 14.3-32 32s14.3 32 32 32z"/></svg>

export const ColorPicker = (props) => {

    const { setCurrentPickedColor, setSelectedElement } = useSettingsStorageDispatch();
    const settingsStorageState = useSettingsStorageState();
    const selectedMenuName = () => settingsStorageState.selectedMenuName

    let colorpicker

    onMount(()=>{
        colorpicker = Pickr.create({
            // Selector or element which will be replaced with the actual color-picker.
            // Can be a HTMLElement.
            el: `#${props?.name}-colorpicker`,

            // Where the pickr-app should be added as child.
            container: 'body',

            // Which theme you want to use. Can be 'classic', 'monolith' or 'nano'
            theme: 'classic',

            // Nested scrolling is currently not supported and as this would be really sophisticated to add this
            // it's easier to set this to true which will hide pickr if the user scrolls the area behind it.
            closeOnScroll: false,

            // Custom class which gets added to the pcr-app. Can be used to apply custom styles.
            appClass: 'custom-colorpicker',

            // Don't replace 'el' Element with the pickr-button, instead use 'el' as a button.
            // If true, appendToBody will also be automatically true.
            useAsButton: true,

            // Size of gap between pickr (widget) and the corresponding reference (button) in px
            padding: 8,

            // If true pickr won't be floating, and instead will append after the in el resolved element.
            // It's possible to hide it via .hide() anyway.
            inline: false,

            // If true, pickr will be repositioned automatically on page scroll or window resize.
            // Can be set to false to make custom positioning easier.
            autoReposition: true,

            // Defines the direction in which the knobs of hue and opacity can be moved.
            // 'v' => opacity- and hue-slider can both only moved vertically.
            // 'hv' => opacity-slider can be moved horizontally and hue-slider vertically.
            // Can be used to apply custom layouts
            sliders: 'v',

            // Start state. If true 'disabled' will be added to the button's classlist.
            disabled: false,

            // If true, the user won't be able to adjust any opacity.
            // Opacity will be locked at 1 and the opacity slider will be removed.
            // The HSVaColor object also doesn't contain an alpha, so the toString() methods just
            // print HSV, HSL, RGB, HEX, etc.
            lockOpacity: false,

            // Precision of output string (only effective if components.interaction.input is true)
            outputPrecision: 0,

            // Defines change/save behavior:
            // - to keep current color in place until Save is pressed, set to `true`,
            // - to apply color to button and preview (save) in sync with each change
            //   (from picker or palette), set to `false`.
            comparison: true,

            // Default color. If you're using a named color such as red, white ... set
            // a value for defaultRepresentation too as there is no button for named-colors.
            default: '#42445a',

            // Optional color swatches. When null, swatches are disabled.
            // Types are all those which can be produced by pickr e.g. hex(a), hsv(a), hsl(a), rgb(a), cmyk, and also CSS color names like 'magenta'.
            // Example: swatches: ['#F44336', '#E91E63', '#9C27B0', '#673AB7'],
            swatches: ['#F44336', '#E91E63', '#9C27B0', '#673AB7', '#8ad4eb','#fd625e','#ffffff','#000000','#a66999','#fe9666','#f2c80f','#C0C0C0','#808080','#000080','#0000FF','#008080','#00FFFF'],

            // Default color representation of the input/output textbox.
            // Valid options are `HEX`, `RGBA`, `HSVA`, `HSLA` and `CMYK`.
            defaultRepresentation: 'HEX',

            // Option to keep the color picker always visible.
            // You can still hide / show it via 'pickr.hide()' and 'pickr.show()'.
            // The save button keeps its functionality, so still fires the onSave event when clicked.
            showAlways: false,

            // Close pickr with a keypress.
            // Default is 'Escape'. Can be the event key or code.
            // (see: https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key)
            closeWithKey: 'Escape',

            // Defines the position of the color-picker.
            // Any combinations of top, left, bottom or right with one of these optional modifiers: start, middle, end
            // Examples: top-start / right-end
            // If clipping occurs, the color picker will automatically choose its position.
            // Pickr uses https://github.com/Simonwep/nanopop as positioning-engine.
            position: selectedMenuName() === "Speedo" ? 'left-middle':'right-middle',

            // Enables the ability to change numbers in an input field with the scroll-wheel.
            // To use it set the cursor on a position where a number is and scroll, use ctrl to make steps of five
            adjustableNumbers: true,

            // Show or hide specific components.
            // By default only the palette (and the save button) is visible.
            components: {

                // Defines if the palette itself should be visible.
                // Will be overwritten with true if preview, opacity or hue are true
                palette: true,

                preview: false, // Display comparison between previous state and new color
                opacity: true, // Display opacity slider
                hue: true,     // Display hue slider

                // show or hide components on the bottom interaction bar.
                interaction: {

                    // Buttons, if you disable one but use the format in default: or setColor() - set the representation-type too!
                    hex: true,  // Display 'input/output format as hex' button  (hexadecimal representation of the rgba value)
                    rgba: true, // Display 'input/output format as rgba' button (red green blue and alpha)
                    hsla: false, // Display 'input/output format as hsla' button (hue saturation lightness and alpha)
                    hsva: false, // Display 'input/output format as hsva' button (hue saturation value and alpha)
                    cmyk: false, // Display 'input/output format as cmyk' button (cyan mangenta yellow key )

                    input: true, // Display input/output textbox which shows the selected color value.
                    // the format of the input is determined by defaultRepresentation,
                    // and can be changed by the user with the buttons set by hex, rgba, hsla, etc (above).
                    cancel: false, // Display Cancel Button, resets the color to the previous state
                    clear: false, // Display Clear Button; same as cancel, but keeps the window open
                    save: false,  // Display Save Button,
                },
            },

            // Translations, these are the default values.
            i18n: {

                // Strings visible in the UI
                'ui:dialog': 'color picker dialog',
                'btn:toggle': 'toggle color picker dialog',
                'btn:swatch': 'color swatch',
                'btn:last-color': 'use previous color',
                'btn:save': 'Save',
                'btn:cancel': 'Cancel',
                'btn:clear': 'Clear',

                // Strings used for aria-labels
                'aria:btn:save': 'save and close',
                'aria:btn:cancel': 'cancel and close',
                'aria:btn:clear': 'clear and close',
                'aria:input': 'color input field',
                'aria:palette': 'color selection area',
                'aria:hue': 'hue selection slider',
                'aria:opacity': 'selection slider'
            }
        });
    })

    const handleClick = () =>{
        setSelectedElement(props?.name)
        colorpicker.on('init',instance =>{
        }).on('change',(color, source, instance) =>{
            setCurrentPickedColor(color.toHEXA().toString())
        })
    }

    return (
        <div>
           <button id={`${props?.name}-colorpicker`} class={`${props?.isActive ? 'bg-red-400': ''} p-2 bg-[#0087D0] rounded-md hover:scale-125 ease-out duration-300`} onClick={handleClick}>
               <ColorPaletteIcon/>
           </button>
        </div>
    );
};