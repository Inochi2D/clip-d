module layer;


/**
    Clip Studio Paint blending modes
*/
enum BlendingMode : string
{
	PassThrough = "pass through",
	Normal = "normal",
	Dissolve = "dissolve",
	Darken = "darken",
	Multiply = "multiply",
	ColorBurn = "burn",
	LinearBurn = "linear_burn",
	DarkerColor = "darker color",
	Lighten = "lighter color",
	Screen = "screen",
	ColorDodge = "dodge",
	LinearDodge = "linear_dodge",
	LighterColor = "lighter color",
	Overlay = "overlay",
	SoftLight = "soft_light",
	HardLight = "hard_light",
	VividLight = "vivid_light",
	LinearLight = "linear light",
	PinLight = "pin_light",
	HardMix = "hard mix",
	Difference = "diff",
	Exclusion = "exclusion",
	Subtract = "subtract",
	Divide = "divide",
	Hue = "hue",
	Saturation = "saturation",
	Color = "color",
	Luminosity = "luminize"
}

/**
    The different types of layer
*/
enum LayerType
{
	/**
        Any other type of layer
    */
	Any = 0,

	/**
        An open folder
    */
	OpenFolder = 1,

	/**
        A closed folder
    */
	ClosedFolder = 2,

	/**
        A bounding section divider
    
        Hidden in the UI
    */
	SectionDivider = 3
}

struct Layer {
    

	/**
	 * The type of layer
	 */
	LayerType type;

	/**
	 * Blending mode
	 */
	BlendingMode blendModeKey;

	/**
	 * Opacity of the layer
	*/
	int opacity;

	/**
	 * Whether the layer is visible or not
	*/
	bool isVisible;
}