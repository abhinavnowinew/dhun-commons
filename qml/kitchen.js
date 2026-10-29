.pragma library
.import "data.js" as Data
.import "logic.js" as Logic

// The kitchen planner is deterministic and runs offline. A local vision model
// may read a menu photograph into this same dish vocabulary, but the planner
// never needs a network connection and never claims live farm inventory.

var MODEL_PROMPT = "You are reading a photograph of a food menu for a farm kitchen. " +
    "Return strict JSON only, with no markdown: " +
    "{\"dishes\":[{\"name\":\"printed dish name\"}],\"servings\":null,\"notes\":[\"anything unclear\"]}. " +
    "Transcribe the printed dish names as written. Do not invent dishes. " +
    "If the photograph is unreadable, return {\"dishes\":[],\"servings\":null,\"notes\":[\"unreadable\"]}.";

var unitGrams = {
    kg: 1000,
    litre: 1000,
    bunch: 100,
    jar: 500,
    dozen: 600,
    box: 100
};

// Grams per guest are edible-portion planning figures, not a recipe.
var dishLibrary = [
    {
        id: "bajra_roti", name: "Bajra Roti", aliases: ["bajra roti", "bajre ki roti", "bajra"],
        kind: "bread", perHead: { bajra: 100, ghee: 6 },
        note: "Millet roti, usually the first bread on a Rajasthani thali."
    },
    {
        id: "jowar_bhakri", name: "Jowar Bhakri", aliases: ["jowar bhakri", "jowar roti", "bhakri", "jowar"],
        kind: "bread", perHead: { jowar: 100, ghee: 4 },
        note: "Soft sorghum flatbread, hand-patted."
    },
    {
        id: "gehun_roti", name: "Gehun Roti", aliases: ["gehun roti", "wheat roti", "chapati", "roti", "gehun"],
        kind: "bread", perHead: { gehun: 90, ghee: 4 },
        note: "Stone-milled wheat roti."
    },
    {
        id: "moth_dal", name: "Moth Dal", aliases: ["moth dal", "moth"],
        kind: "dal", perHead: { moth: 40, ghee: 5, dhaniya: 5, nimbu: 3 },
        note: "Small desert beans, quick-cooked and finished with lime."
    },
    {
        id: "mung_khichdi", name: "Mung Khichdi", aliases: ["mung khichdi", "moong khichdi", "khichdi", "mung"],
        kind: "grain", perHead: { mung: 45, gehun: 50, ghee: 5, dhaniya: 4 },
        note: "Mung and broken wheat, cooked soft."
    },
    {
        id: "sarson_saag", name: "Sarson Saag", aliases: ["sarson saag", "sarson ka saag", "mustard greens", "sarson"],
        kind: "veg", perHead: { sarson: 140, ghee: 8, dhaniya: 3 },
        note: "Peppery mustard greens, slow-cooked."
    },
    {
        id: "palak_saag", name: "Palak Saag", aliases: ["palak saag", "palak", "spinach"],
        kind: "veg", perHead: { palak: 130, ghee: 6 },
        note: "Tender spinach, lightly cooked."
    },
    {
        id: "methi_paratha", name: "Methi Paratha", aliases: ["methi paratha", "methi", "fenugreek"],
        kind: "bread", perHead: { methi: 55, gehun: 70, ghee: 6 },
        note: "Fenugreek folded into wheat paratha."
    },
    {
        id: "bhindi_masala", name: "Bhindi Masala", aliases: ["bhindi masala", "bhindi", "okra"],
        kind: "veg", perHead: { bhindi: 110, til: 3 },
        note: "Small okra pods, dry-roasted."
    },
    {
        id: "lauki_sabzi", name: "Lauki Sabzi", aliases: ["lauki sabzi", "lauki", "bottle gourd"],
        kind: "veg", perHead: { lauki: 130, til: 2 },
        note: "Light bottle-gourd curry."
    },
    {
        id: "petha_sabzi", name: "Petha Sabzi", aliases: ["petha sabzi", "petha", "ash gourd"],
        kind: "veg", perHead: { petha: 130, til: 2 },
        note: "Dense ash gourd, slow-cooked."
    },
    {
        id: "tamatar_rasam", name: "Tamatar Rasam", aliases: ["tamatar rasam", "tomato rasam", "rasam", "tamatar"],
        kind: "dal", perHead: { tamatar: 90, curry_patta: 2, nimbu: 3 },
        note: "Thin tomato broth tempered with curry leaf."
    },
    {
        id: "baingan_bharta", name: "Baingan Bharta", aliases: ["baingan bharta", "bharta", "baingan", "brinjal"],
        kind: "veg", perHead: { baingan: 120, ghee: 4, dhaniya: 3 },
        note: "Smoked brinjal, mashed with ghee."
    },
    {
        id: "matar_sabzi", name: "Matar Sabzi", aliases: ["matar sabzi", "matar", "peas"],
        kind: "veg", perHead: { matar: 90, ghee: 4 },
        note: "Fresh garden peas."
    },
    {
        id: "kheera_raita", name: "Kheera Raita", aliases: ["kheera raita", "cucumber raita", "raita", "kheera"],
        kind: "dairy", perHead: { kheera: 80, doodh: 45, pudina: 2 },
        note: "Cucumber folded into curd."
    },
    {
        id: "gajar_halwa", name: "Gajar Halwa", aliases: ["gajar halwa", "gajar ka halwa", "carrot halwa", "gajar"],
        kind: "sweet", perHead: { gajar: 110, doodh: 50, ghee: 6, til: 2 },
        note: "Winter carrots cooked down in milk."
    },
    {
        id: "chana_curry", name: "Chana Curry", aliases: ["chana curry", "chole", "chana"],
        kind: "dal", perHead: { chana: 45, tamatar: 40, ghee: 4 },
        note: "Desi chickpeas in a tomato gravy."
    },
    {
        id: "guar_sabzi", name: "Guar Sabzi", aliases: ["guar sabzi", "guar", "cluster bean"],
        kind: "veg", perHead: { guar: 110, til: 2 },
        note: "Cluster beans with a clean bitter edge."
    },
    {
        id: "besan_gatta", name: "Besan Gatta", aliases: ["besan gatta", "gatta", "gatte"],
        kind: "dal", perHead: { chana: 40, doodh: 30, ghee: 4 },
        note: "Chickpea-flour dumplings in a yoghurt gravy."
    },
    {
        id: "anar_chaat", name: "Anar Chaat", aliases: ["anar chaat", "anar", "pomegranate"],
        kind: "fruit", perHead: { anar: 70, nimbu: 5, pudina: 2 },
        note: "Pomegranate arils with lime and mint."
    },
    {
        id: "amrud_chutney", name: "Amrud Chutney", aliases: ["amrud chutney", "guava chutney", "amrud"],
        kind: "condiment", perHead: { amrud: 45, nimbu: 4, pudina: 2 },
        note: "Fragrant guava chutney."
    },
    {
        id: "dhaniya_chutney", name: "Dhaniya Chutney", aliases: ["dhaniya chutney", "coriander chutney", "dhaniya"],
        kind: "condiment", perHead: { dhaniya: 30, pudina: 10, nimbu: 8 },
        note: "Coriander and mint, ground fresh."
    },
    {
        id: "nimbu_pani", name: "Nimbu Pani", aliases: ["nimbu pani", "lime water", "lemonade", "nimbu"],
        kind: "drink", perHead: { nimbu: 12, pudina: 2 },
        note: "Lime and mint, served cold."
    },
    {
        id: "kharbooja_cooler", name: "Kharbooja Cooler", aliases: ["kharbooja cooler", "muskmelon", "kharbooja"],
        kind: "drink", perHead: { kharbooja: 140, nimbu: 5, pudina: 2 },
        note: "Muskmelon blended with lime."
    },
    {
        id: "tarbooz_cooler", name: "Tarbooz Cooler", aliases: ["tarbooz cooler", "watermelon", "tarbooz"],
        kind: "drink", perHead: { tarbooz: 160, nimbu: 4 },
        note: "Watermelon, pressed and chilled."
    },
    {
        id: "aam_panna", name: "Aam Panna", aliases: ["aam panna", "aam", "mango"],
        kind: "drink", perHead: { aam: 70, pudina: 2, nimbu: 4 },
        note: "Green mango cooler."
    },
    {
        id: "amla_murabba", name: "Amla Murabba", aliases: ["amla murabba", "amla", "gooseberry"],
        kind: "preserve", perHead: { amla: 50 },
        note: "Amla in sugar syrup, served in a small dish."
    },
    {
        id: "besan_chilla", name: "Besan Chilla", aliases: ["besan chilla", "chilla", "pudla"],
        kind: "bread", perHead: { chana: 45, ghee: 3, dhaniya: 3 },
        note: "Chickpea-flour pancake."
    },
    {
        id: "mung_sprouts", name: "Mung Sprouts", aliases: ["mung sprouts", "sprouts"],
        kind: "salad", perHead: { mung: 40, nimbu: 4, pudina: 2 },
        note: "Sprouted mung with lime."
    }
];

var sampleMenus = [
    {
        id: "winter-thali",
        title: "Rabi thali · 24 guests",
        guests: 24,
        season: "rabi",
        month: 12,
        text: "Bajra Roti\nMoth Dal\nSarson Saag\nGajar Halwa\nKheera Raita\nNimbu Pani",
        note: "A winter field lunch built from the rabi beds and the dairy."
    },
    {
        id: "monsoon-thali",
        title: "Kharif thali · 18 guests",
        guests: 18,
        season: "kharif",
        month: 9,
        text: "Jowar Bhakri\nBhindi Masala\nMoth Dal\nAnar Chaat\nTarbooz Cooler",
        note: "Monsoon harvest, with orchard fruit."
    },
    {
        id: "summer-thali",
        title: "Zaid thali · 30 guests",
        guests: 30,
        season: "zaid",
        month: 5,
        text: "Mung Khichdi\nLauki Sabzi\nKheera Raita\nKharbooja Cooler\nAam Panna",
        note: "Hot-season cooking, built around gourds and melons."
    }
];

var wasteUses = {
    bajra: {
        parts: [
            { part: "Bran and sifting", use: "Fold a spoonful into roti dough or the cattle feed; sieve the rest to compost.", caution: "Keep dry; mouldy bran goes only to compost." }
        ]
    },
    jowar: {
        parts: [
            { part: "Bran and sifting", use: "Add to bhakri dough or compost.", caution: "Keep dry; do not use damp flour." }
        ]
    },
    gehun: {
        parts: [
            { part: "Bran", use: "Fold into roti dough for a coarser crumb, or compost.", caution: "Store dry." }
        ]
    },
    moth: {
        parts: [
            { part: "Soaking water", use: "Use the strained soaking water to loosen the dal, then cook it through.", caution: "Do not keep soaking water at room temperature for more than a few hours." },
            { part: "Husks", use: "Compost or feed to poultry after cooking.", caution: "Raw pulse husks are not a people food." }
        ]
    },
    mung: {
        parts: [
            { part: "Sprout hulls", use: "Compost; a clean handful can go into the stock pot.", caution: "Rinse sprouts well; discard any slimy batch." },
            { part: "Soaking water", use: "Use in the cooking liquid.", caution: "Refrigerate if not used within two hours." }
        ]
    },
    chana: {
        parts: [
            { part: "Soaking water", use: "Use as part of the curry liquid.", caution: "Discard if it smells sour." },
            { part: "Husks", use: "Compost.", caution: "Not for people." }
        ]
    },
    guar: {
        parts: [
            { part: "Ends and strings", use: "Compost; the strings are too fibrous to eat.", caution: "Do not serve raw cluster beans." }
        ]
    },
    sarson: {
        parts: [
            { part: "Stalks", use: "Peel the fibrous outer layer and chop the tender inner stalk into the saag.", caution: "Discard woody or hollow stalks." },
            { part: "Roots", use: "Scrub, peel and pickle only if grown in clean soil; otherwise compost.", caution: "Roots carry soil grit; never use roots from unknown ground." }
        ]
    },
    palak: {
        parts: [
            { part: "Stems", use: "Chop into dal or saag; they hold their shape.", caution: "Discard wilted or slimy stems." },
            { part: "Roots", use: "Cut off, wash and compost.", caution: "Do not eat spinach roots." }
        ]
    },
    methi: {
        parts: [
            { part: "Stems", use: "Chop fine into paratha or dal.", caution: "Discard woody stems." },
            { part: "Roots", use: "Compost after washing.", caution: "Not a people food." }
        ]
    },
    bhindi: {
        parts: [
            { part: "Caps and tips", use: "Compost; they stay fibrous.", caution: "Do not add to a smooth gravy." }
        ]
    },
    lauki: {
        parts: [
            { part: "Peel", use: "If unwaxed and well washed, blend into a chutney or stock. Otherwise compost.", caution: "Discard the whole gourd if it tastes bitter." },
            { part: "Seeds", use: "Roast and salt the mature seeds.", caution: "Remove from very young gourds only if soft." }
        ]
    },
    petha: {
        parts: [
            { part: "Peel", use: "Young, unwaxed peel can be candied; older peel goes to compost.", caution: "Wash off field wax and soil." },
            { part: "Seeds", use: "Roast and salt.", caution: "Discard bitter seeds." }
        ]
    },
    tamatar: {
        parts: [
            { part: "Skins and seeds", use: "Blanch, strain and cook the liquid into rasam or a stock.", caution: "Use only sound fruit; discard mouldy tomatoes whole." }
        ]
    },
    baingan: {
        parts: [
            { part: "Calyx and stem", use: "Compost.", caution: "Not edible." },
            { part: "Peels", use: "Roast with the flesh for bharta, or compost.", caution: "Discard peels from bitter fruit." }
        ]
    },
    gajar: {
        parts: [
            { part: "Peels", use: "Wash and simmer into a chutney or stock. Compost the rest.", caution: "Scrub well; peelings carry soil." },
            { part: "Tops", use: "If fresh and tender, grind into a herb chutney.", caution: "Discard wilted tops." }
        ]
    },
    matar: {
        parts: [
            { part: "Pods", use: "Simmer fresh, washed pods into a stock, then strain.", caution: "Discard pods that are mouldy or leathery." }
        ]
    },
    tarbooz: {
        parts: [
            { part: "Rind", use: "Use the pale inner rind in a pickle or chutney; compost the hard green skin.", caution: "Wash the outside before cutting." },
            { part: "Seeds", use: "Roast and salt.", caution: "Spit or strain out the hard hulls." }
        ]
    },
    kharbooja: {
        parts: [
            { part: "Rind", use: "Compost, or pickle the firm inner rind.", caution: "Wash before cutting." },
            { part: "Seeds", use: "Roast and salt.", caution: "Discard bitter seeds." }
        ]
    },
    kheera: {
        parts: [
            { part: "Peel", use: "If unwaxed, stir into raita or infuse in water; otherwise compost.", caution: "Wash well; discard bitter peel." }
        ]
    },
    til: {
        parts: [
            { part: "Hulls", use: "Compost.", caution: "Not a people food." }
        ]
    },
    amla: {
        parts: [
            { part: "Stones", use: "Compost.", caution: "Do not blend stones into a preserve." },
            { part: "Fibrous trim", use: "Simmer into the murabba syrup.", caution: "Discard bruised or mouldy fruit." }
        ]
    },
    ber: {
        parts: [
            { part: "Stones", use: "Compost.", caution: "Not edible." }
        ]
    },
    amrud: {
        parts: [
            { part: "Peels", use: "Grind into chutney if unwaxed; otherwise compost.", caution: "Wash well." },
            { part: "Seeds", use: "Discard or compost.", caution: "Hard seeds; do not blend." }
        ]
    },
    anar: {
        parts: [
            { part: "Peel and pith", use: "Compost, or simmer for a natural dye. Not a food claim.", caution: "Do not eat the outer peel." }
        ]
    },
    nimbu: {
        parts: [
            { part: "Zest", use: "Dry with salt for a citrus salt, or add to pickle.", caution: "Use unwaxed, washed peel." },
            { part: "Peel", use: "Candy the peel or compost.", caution: "Wash off wax." },
            { part: "Seeds", use: "Compost.", caution: "Not edible." }
        ]
    },
    aam: {
        parts: [
            { part: "Peel", use: "Cook into a chutney; compost the rest.", caution: "Use sound fruit only." },
            { part: "Stones", use: "Compost.", caution: "Do not blend." }
        ]
    },
    dhaniya: {
        parts: [
            { part: "Stems", use: "Grind into chutney or simmer into dal.", caution: "Discard slimy stems." },
            { part: "Roots", use: "Wash thoroughly and grind into chutney only from the kitchen garden; otherwise compost.", caution: "Roots hold grit." }
        ]
    },
    pudina: {
        parts: [
            { part: "Stems", use: "Steep in water for a mint infusion, or grind into chutney.", caution: "Strain before serving." },
            { part: "Roots", use: "Compost.", caution: "Not a people food." }
        ]
    },
    moringa: {
        parts: [
            { part: "Stems", use: "Strip the leaves and simmer the tender stems in dal, then remove.", caution: "Discard woody stems." },
            { part: "Roots", use: "Compost.", caution: "Do not eat moringa root." }
        ]
    },
    curry_patta: {
        parts: [
            { part: "Stems", use: "Fry in the tempering oil, then remove before serving.", caution: "Stems are fibrous." }
        ]
    },
    microgreens: {
        parts: [
            { part: "Roots and coir", use: "Compost the tray after harvest.", caution: "Do not eat the coir." }
        ]
    },
    doodh: {
        parts: [
            { part: "Surplus milk", use: "Set curd, make paneer or churn ghee.", caution: "Chill quickly; do not leave raw milk warm." },
            { part: "Whey", use: "Knead into dough or water the compost.", caution: "Keep chilled until used." }
        ]
    },
    ghee: {
        parts: [
            { part: "Jar residue", use: "Use the last spoonful in a dal or roti.", caution: "Discard if rancid." }
        ]
    },
    ande: {
        parts: [
            { part: "Shells", use: "Crush and compost.", caution: "Rinse; do not feed raw shells to poultry." }
        ]
    }
};

var nativeAdditions = [
    {
        id: "moringa",
        name: "Moringa leaves",
        local: "Moringa oleifera",
        pairing: "dal, saag and khichdi",
        action: "Fold a handful of leaves into the dal in the last two minutes, or scatter over the saag.",
        source: "Kitchen garden offer OFF-21 when it is listed; otherwise confirm the day's cut with the field unit.",
        offerId: "OFF-21",
        caution: "Introduce small portions. This is a culinary suggestion, not a nutrition or medical claim.",
        seasons: ["kharif", "zaid"]
    },
    {
        id: "sangri",
        name: "Sangri (khejri pod)",
        local: "Prosopis cineraria",
        pairing: "bajra roti and slow pulses",
        action: "Soak dried pods, discard the water and cook them with moth or chana for a traditional dryland curry.",
        source: "Foraged from designated khejri marker trees with the field crew; not in the weekly produce offers.",
        offerId: "",
        caution: "Harvest only what the field crew marks for use; leave pods for seed and fodder. Introduce small portions.",
        seasons: ["kharif", "rabi", "zaid"]
    },
    {
        id: "ker",
        name: "Ker buds",
        local: "Capparis decidua",
        pairing: "pickle and condiment plate",
        action: "Pickle dried ker buds with salt, oil and spice as a small side for the thali.",
        source: "Foraged thorn-scrub bud; confirm the harvest with the field unit.",
        offerId: "",
        caution: "Thorns and hard seeds; use only properly prepared pickle. Introduce small portions.",
        seasons: ["rabi", "zaid"]
    },
    {
        id: "gunda",
        name: "Gunda / lasoda",
        local: "Cordia dichotoma",
        pairing: "pickle and sour side",
        action: "Pickle the sticky green fruit, or cook it into a sour side with salt and oil.",
        source: "Foraged homestead fruit; not in the weekly produce offers.",
        offerId: "",
        caution: "Remove stones; use only sound fruit. Introduce small portions.",
        seasons: ["zaid", "kharif"]
    },
    {
        id: "amla",
        name: "Amla",
        local: "Phyllanthus emblica",
        pairing: "murabba and winter pantry",
        action: "Make a small batch of amla murabba for the memorabilia shelf, or serve a spoonful beside the thali.",
        source: "Orchard fruit when the season and offers allow; this week's seed offers do not include amla.",
        offerId: "",
        caution: "High-sugar preserve. This is not a health claim; check allergies and serve small portions.",
        seasons: ["rabi"]
    },
    {
        id: "ber",
        name: "Ber",
        local: "Ziziphus mauritiana",
        pairing: "chutney and fresh fruit",
        action: "Grind ripe ber into a sour chutney, or serve whole as a small fruit course.",
        source: "Orchard edge when in season; confirm the lot with the field unit.",
        offerId: "",
        caution: "Hard stones; remove before blending. Introduce small portions.",
        seasons: ["rabi"]
    }
];

var preservationMethods = [
    {
        id: "dried_roti",
        name: "Dried roti crisps",
        days: 28,
        daysLabel: "3–4 weeks",
        input: "cooked breads",
        gate: "cooked",
        unitLabel: "200 g tins",
        steps: [
            "Cool the rotis completely within two hours of cooking.",
            "Tear into pieces and dry at 60–70 °C, or in a solar dryer, until brittle.",
            "Cool, pack airtight with a moisture absorber, label every tin."
        ],
        caveat: "Only from breads kept out of service and never taken to a guest plate. Discard if soft or musty. Contains gluten."
    },
    {
        id: "veg_pickle",
        name: "Oil-and-salt cooked vegetable pickle",
        days: 28,
        daysLabel: "3–4 weeks refrigerated",
        input: "cooked vegetable curries",
        gate: "cooked",
        requiresRefrigeration: true,
        unitLabel: "250 g jars",
        steps: [
            "Use only a curry that was cooled within two hours and refrigerated untouched.",
            "Re-cook with a little more oil and salt, pack into clean dry jars while hot.",
            "Cool, refrigerate, and use a dry spoon for every serving."
        ],
        caveat: "Refrigerated only. High oil and salt. Discard at the first sign of mould or an off smell. Not suitable for every diet."
    },
    {
        id: "dal_papad",
        name: "Dehydrated dal papad",
        days: 35,
        daysLabel: "4–5 weeks",
        input: "cooked dal",
        gate: "cooked",
        requiresDehydrator: true,
        unitLabel: "100 g packs",
        steps: [
            "Blend cooled, untouched dal to a thick paste.",
            "Spread thin and dry in a dehydrator until it snaps, not bends.",
            "Pack airtight with a moisture absorber; label the batch."
        ],
        caveat: "Requires a dehydrator and a fully dry snap. If there is any doubt, freeze or compost. Never sun-dry cooked dal in humid weather."
    },
    {
        id: "citrus_salt",
        name: "Citrus-and-herb salt",
        days: 120,
        daysLabel: "4 months",
        input: "lime peel and herb stems",
        gate: "trim",
        unitLabel: "80 g jars",
        steps: [
            "Zest unwaxed, washed limes and chop clean herb stems.",
            "Rub with coarse salt and dry completely.",
            "Pack dry, label, and keep away from steam."
        ],
        caveat: "Use only unwaxed peel. High salt; not a medicine and not a low-sodium ingredient."
    },
    {
        id: "seed_powder",
        name: "Roasted seed chutney powder",
        days: 45,
        daysLabel: "6 weeks",
        input: "sesame and pulse trims",
        gate: "trim",
        unitLabel: "100 g jars",
        steps: [
            "Toast sesame or clean pulse trims until fragrant.",
            "Cool completely, grind coarse with salt and dried herbs.",
            "Pack airtight; label allergens."
        ],
        caveat: "Contains seeds. Check allergies before serving. Discard if rancid."
    },
    {
        id: "fruit_pickle",
        name: "Amla, lime or mango pickle",
        days: 90,
        daysLabel: "3 months",
        input: "raw fruit",
        gate: "raw",
        unitLabel: "250 g jars",
        steps: [
            "Use sound, dry fruit and clean, dry jars.",
            "Layer with salt and oil; keep the surface covered.",
            "Label and store cool and dark; use a dry spoon."
        ],
        caveat: "High salt and oil. Follow a tested recipe for your fruit. Discard if mould appears."
    },
    {
        id: "fruit_murabba",
        name: "Amla or ash-gourd murabba",
        days: 120,
        daysLabel: "4 months",
        input: "raw fruit",
        gate: "raw",
        unitLabel: "200 g jars",
        steps: [
            "Cook sound fruit in sugar syrup until glossy and saturated.",
            "Pack hot into clean jars and seal.",
            "Label the batch and store cool and dark."
        ],
        caveat: "Very high sugar. Not a health food; serve small portions. Discard if the seal fails."
    },
    {
        id: "sun_dried_veg",
        name: "Sun-dried vegetable strips",
        days: 60,
        daysLabel: "2 months",
        input: "raw vegetables",
        gate: "raw",
        unitLabel: "100 g packs",
        steps: [
            "Slice clean vegetables thinly and blanch where the crop needs it.",
            "Dry in strong sun and dry air until leathery, bringing trays in at night.",
            "Pack airtight with a moisture absorber; label."
        ],
        caveat: "Only in dry weather. Rehydrate and cook before eating. Discard if damp or musty."
    },
    {
        id: "ghee",
        name: "Cultured ghee from surplus milk",
        days: 180,
        daysLabel: "6 months",
        input: "milk and cream",
        gate: "dairy",
        requiresRefrigeration: false,
        unitLabel: "200 ml jars",
        steps: [
            "Culture the cream, then churn or blend to butter.",
            "Simmer gently until the milk solids are spent and the moisture is gone.",
            "Strain into dry jars, label, and keep cool and dark."
        ],
        caveat: "Use only properly chilled milk and cream. Discard if rancid. Contains milk."
    },
    {
        id: "compost",
        name: "Compost or animal feed",
        days: 0,
        daysLabel: "same day",
        input: "any trim or failed batch",
        gate: "always",
        unitLabel: "feed bins",
        steps: [
            "Sort out packaging, stones and bones.",
            "Take cooked food to the compost or the farm animals the same day.",
            "Cover the bin and record the batch."
        ],
        caveat: "This is the safe route when the preservation gate is not met. Do not feed plate waste to guests or animals."
    }
];

function hash32(text) {
    var h = 0x811c9dc5;
    var value = String(text);
    for (var i = 0; i < value.length; ++i) {
        h ^= value.charCodeAt(i);
        h = Math.imul(h, 0x01000193) >>> 0;
    }
    return h >>> 0;
}

function clampInt(value, min, max) {
    var number = Math.round(Number(value) || 0);
    if (number < min) return min;
    if (number > max) return max;
    return number;
}

function roundTo(value, step) {
    var s = Number(step) || 1;
    var n = Number(value) || 0;
    return Math.round(n / s) * s;
}

function ceilTo(value, step) {
    var s = Number(step) || 1;
    var n = Number(value) || 0;
    return Math.ceil((n - 0.000001) / s) * s;
}

function qty(value) {
    var number = Number(value) || 0;
    if (Math.abs(number - Math.round(number)) < 0.001) return String(Math.round(number));
    return String(Math.round(number * 100) / 100);
}

function purchaseStep(unit) {
    if (unit === "kg" || unit === "litre") return 0.05;
    if (unit === "dozen" || unit === "jar" || unit === "box") return 1;
    if (unit === "bunch") return 1;
    return 0.05;
}

function unitWeight(unit) {
    return unitGrams[unit] || 1000;
}

function trimFactor(ingredient) {
    if (!ingredient) return 1.1;
    if (ingredient.category === "Herb") return 1.3;
    if (ingredient.category === "Vegetable") return 1.15;
    if (ingredient.category === "Fruit") return 1.2;
    if (ingredient.category === "Grain" || ingredient.category === "Pulse" || ingredient.category === "Seed") return 1.02;
    if (ingredient.category === "Dairy" || ingredient.category === "Poultry") return 1.02;
    return 1.1;
}

function normalize(text) {
    return String(text === undefined || text === null ? "" : text)
        .toLowerCase()
        .replace(/[·•|/]/g, " ")
        .replace(/[^a-z0-9\s]/g, " ")
        .replace(/\s+/g, " ")
        .trim();
}

function dishById(id) {
    for (var i = 0; i < dishLibrary.length; ++i) {
        if (dishLibrary[i].id === id) return dishLibrary[i];
    }
    return null;
}

function dishChoices() {
    var result = [];
    for (var i = 0; i < dishLibrary.length; ++i) {
        result.push({ id: dishLibrary[i].id, name: dishLibrary[i].name, kind: dishLibrary[i].kind });
    }
    return result;
}

function sampleMenuById(id) {
    for (var i = 0; i < sampleMenus.length; ++i) {
        if (sampleMenus[i].id === id) return sampleMenus[i];
    }
    return sampleMenus[0];
}

function seasonForMonth(month) {
    var m = Number(month) || (new Date().getMonth() + 1);
    if (m >= 7 && m <= 10) return Data.seasonById("kharif");
    if (m >= 11 || m <= 3) return Data.seasonById("rabi");
    return Data.seasonById("zaid");
}

function dishForLine(line) {
    var text = normalize(line);
    if (!text) return null;
    var best = null;
    var bestLength = 0;
    for (var i = 0; i < dishLibrary.length; ++i) {
        var dish = dishLibrary[i];
        var aliases = dish.aliases || [];
        for (var j = 0; j < aliases.length; ++j) {
            var alias = normalize(aliases[j]);
            if (alias.length >= 3 && text.indexOf(alias) !== -1 && alias.length > bestLength) {
                best = dish;
                bestLength = alias.length;
            }
        }
    }
    return best;
}

function parseMenu(text) {
    var lines = String(text === undefined || text === null ? "" : text).split(/[\n;]+/);
    var dishes = [];
    var seenDish = {};
    var extras = [];
    var seenExtra = {};
    var unmatched = [];
    var guests = 0;

    var guestMatch = String(text || "").match(/(\d{1,3})\s*(?:guests?|people|persons?|pax|heads?)/i);
    if (guestMatch) guests = clampInt(guestMatch[1], 1, 500);

    for (var i = 0; i < lines.length; ++i) {
        var line = lines[i].replace(/^[\s\-*•]+/, "").trim();
        if (!line) continue;
        var dish = dishForLine(line);
        if (dish) {
            if (!seenDish[dish.id]) {
                seenDish[dish.id] = true;
                dishes.push({ id: dish.id, name: dish.name, kind: dish.kind, matchedBy: line });
            }
            continue;
        }
        var foundIngredient = false;
        for (var k = 0; k < Data.ingredients.length; ++k) {
            var ingredient = Data.ingredients[k];
            if (normalize(line).indexOf(normalize(ingredient.name)) !== -1) {
                if (!seenExtra[ingredient.id]) {
                    seenExtra[ingredient.id] = true;
                    extras.push({ id: ingredient.id, name: ingredient.name, gramsPerHead: 100 });
                }
                foundIngredient = true;
            }
        }
        if (!foundIngredient) unmatched.push(line);
    }

    return {
        dishes: dishes,
        extras: extras,
        unmatched: unmatched,
        suggestedGuests: guests,
        matched: dishes.length + extras.length
    };
}

function requirementsFor(parsed, guests) {
    var requirements = {};
    var usedBy = {};
    var count = clampInt(guests, 1, 500);

    function add(id, gramsPerHead, source) {
        if (!requirements[id]) {
            requirements[id] = 0;
            usedBy[id] = [];
        }
        requirements[id] += Number(gramsPerHead) || 0;
        if (source && usedBy[id].indexOf(source) === -1) usedBy[id].push(source);
    }

    for (var i = 0; i < parsed.dishes.length; ++i) {
        var dish = dishById(parsed.dishes[i].id);
        if (!dish) continue;
        var keys = Object.keys(dish.perHead);
        for (var j = 0; j < keys.length; ++j) add(keys[j], dish.perHead[keys[j]], dish.name);
    }
    for (var k = 0; k < parsed.extras.length; ++k) {
        add(parsed.extras[k].id, parsed.extras[k].gramsPerHead, "Menu line: " + parsed.extras[k].name);
    }

    var ids = Object.keys(requirements);
    var result = [];
    for (var n = 0; n < ids.length; ++n) {
        result.push({
            ingredientId: ids[n],
            gramsPerHead: requirements[ids[n]],
            gramsTotal: requirements[ids[n]] * count,
            usedBy: usedBy[ids[n]]
        });
    }
    result.sort(function (a, b) { return b.gramsTotal - a.gramsTotal; });
    return result;
}

function offerCost(offer, need) {
    if (!offer) return 0;
    return Math.min(Number(need) || 0, Number(offer.stock) || 0) * (Number(offer.price) || 0);
}

function buildSourcingLine(state, requirement, month) {
    var ingredient = Data.ingredientById(requirement.ingredientId);
    if (!ingredient) return null;
    var offer = Logic.findProduceOffer(state, ingredient.id);
    var unit = offer ? String(offer.unit || ingredient.unit) : ingredient.unit;
    var perUnit = unitWeight(unit);
    var step = purchaseStep(unit);
    var needUnits = (requirement.gramsTotal / 1000) * trimFactor(ingredient) /
        (perUnit / 1000);
    needUnits = ceilTo(needUnits, step);
    var stock = offer ? Number(offer.stock) || 0 : 0;
    var coverageUnits = Math.min(needUnits, stock);
    var shortfall = Math.max(0, needUnits - stock);
    var inSeason = Data.isInSeason(ingredient, month);
    var plot = Data.plotFor(ingredient);
    var grower = Data.growerFor(ingredient);
    var status = "absent";
    if (offer && stock >= needUnits) status = "covered";
    else if (offer && stock > 0) status = "partial";
    else if (!offer) status = "plot";

    return {
        id: ingredient.id,
        name: ingredient.name,
        local: ingredient.local,
        botanical: ingredient.botanical,
        category: ingredient.category,
        zone: ingredient.zone,
        zoneName: ingredient.zoneName,
        unit: unit,
        need: needUnits,
        needLabel: qty(needUnits) + " " + unit,
        gramsPerHead: requirement.gramsPerHead,
        gramsTotal: requirement.gramsTotal,
        stock: stock,
        stockLabel: offer ? qty(stock) + " " + unit : "no Market lot",
        coverage: offer && needUnits > 0 ? Math.min(1, stock / needUnits) : 0,
        shortfall: shortfall,
        shortfallLabel: shortfall > 0 ? qty(shortfall) + " " + unit : "",
        price: offer ? Number(offer.price) || 0 : Number(ingredient.price) || 0,
        cost: offer ? offerCost(offer, needUnits) : needUnits * (Number(ingredient.price) || 0),
        estimated: !offer,
        offerId: offer ? offer.id : "",
        supplier: offer ? offer.supplier : grower.name,
        growerId: offer ? offer.growerId : grower.id,
        status: status,
        inSeason: inSeason,
        seasonLabel: Data.seasonLabelForIngredient(ingredient),
        monthNote: inSeason ? "In season for planning month " + month + "." :
            "Out of season for planning month " + month + "; stock shown is the rehearsal offer, not a live harvest promise.",
        usedBy: requirement.usedBy,
        photo: Data.photoFor(ingredient),
        plot: plot
    };
}

function groupByZone(lines) {
    var groups = [];
    var index = {};
    for (var i = 0; i < lines.length; ++i) {
        var line = lines[i];
        if (!index[line.zone]) {
            var zone = Data.zoneById(line.zone);
            index[line.zone] = {
                zone: line.zone,
                zoneName: line.zoneName,
                color: zone ? zone.color : "#8FA6B2",
                latitude: zone ? zone.latitude : Data.site.latitude,
                longitude: zone ? zone.longitude : Data.site.longitude,
                cost: 0,
                lines: []
            };
            groups.push(index[line.zone]);
        }
        index[line.zone].cost += line.cost;
        index[line.zone].lines.push(line);
    }
    return groups;
}

function wasteFor(lines) {
    var result = [];
    for (var i = 0; i < lines.length; ++i) {
        var use = wasteUses[lines[i].id];
        if (!use) continue;
        result.push({
            ingredientId: lines[i].id,
            name: lines[i].name,
            parts: use.parts
        });
    }
    return result;
}

function nativesFor(parsed, lines, month) {
    var season = seasonForMonth(month);
    var seasonId = season ? season.id : "";
    var result = [];
    var usedIds = {};
    var kinds = {};
    for (var i = 0; i < lines.length; ++i) usedIds[lines[i].id] = true;
    for (var d = 0; d < parsed.dishes.length; ++d) {
        var dish = dishById(parsed.dishes[d].id);
        if (dish) kinds[dish.kind] = true;
    }
    for (var n = 0; n < nativeAdditions.length && result.length < 3; ++n) {
        var item = nativeAdditions[n];
        var seasonal = item.seasons.indexOf(seasonId) !== -1;
        var fits = false;
        if (item.id === "moringa") fits = !!(kinds.dal || kinds.grain || kinds.veg || usedIds.moringa);
        else if (item.id === "sangri") fits = !!(usedIds.bajra || usedIds.jowar || usedIds.moth || usedIds.chana);
        else if (item.id === "ker" || item.id === "gunda") fits = !!(kinds.condiment || kinds.veg || kinds.dal);
        else if (item.id === "amla") fits = !!(kinds.preserve || kinds.sweet || usedIds.amla);
        else if (item.id === "ber") fits = !!(kinds.condiment || kinds.fruit || kinds.drink);
        if (fits || (result.length < 2 && seasonal)) {
            result.push({
                id: item.id,
                name: item.name,
                local: item.local,
                pairing: item.pairing,
                action: item.action,
                source: item.source,
                offerId: item.offerId,
                caution: item.caution,
                inSeason: seasonal,
                seasonNote: seasonal ? "In its natural season for this planning month." :
                    "Outside its main season; confirm availability with the field unit."
            });
        }
    }
    return result;
}

function safetyBlockers(method, safety) {
    var blockers = [];
    var gate = safety || {};
    if (method.gate === "cooked") {
        if (!gate.cooledWithin2h) blockers.push("Food was not cooled within two hours.");
        if (!gate.refrigerated) blockers.push("Food was not kept refrigerated.");
        if (!gate.untouched) blockers.push("Food went into service or touched guest plates.");
    }
    if (method.requiresDehydrator && !gate.dehydrator)
        blockers.push("No dehydrator is available for a fully dry product.");
    if (method.requiresRefrigeration && !gate.refrigerated)
        blockers.push("Refrigeration is required for this method.");
    return blockers;
}

function applicableInputs(parsed) {
    var kinds = {};
    var ids = {};
    for (var i = 0; i < parsed.dishes.length; ++i) {
        var dish = dishById(parsed.dishes[i].id);
        if (!dish) continue;
        kinds[dish.kind] = true;
        var keys = Object.keys(dish.perHead);
        for (var j = 0; j < keys.length; ++j) ids[keys[j]] = true;
    }
    return {
        kinds: kinds,
        ids: ids,
        has: function (kind) { return !!kinds[kind]; },
        any: function (list) {
            for (var k = 0; k < list.length; ++k) if (ids[list[k]]) return true;
            return false;
        }
    };
}

function methodFits(method, inputs) {
    if (method.id === "compost") return true;
    if (method.id === "dried_roti") return inputs.has("bread");
    if (method.id === "veg_pickle") return inputs.has("veg") || inputs.has("dal");
    if (method.id === "dal_papad") return inputs.has("dal") || inputs.has("grain");
    if (method.id === "citrus_salt") return inputs.any(["nimbu"]);
    if (method.id === "seed_powder") return inputs.any(["til", "moth", "mung", "chana"]);
    if (method.id === "fruit_pickle") return inputs.any(["amla", "nimbu", "aam", "ber", "gunda", "ker"]);
    if (method.id === "fruit_murabba") return inputs.any(["amla", "petha", "gajar"]);
    if (method.id === "sun_dried_veg") return inputs.has("veg");
    if (method.id === "ghee") return inputs.any(["doodh"]);
    return false;
}

function jarsFor(method, guests) {
    var count = clampInt(guests, 1, 500);
    if (method.id === "citrus_salt") return Math.max(1, Math.ceil(count / 20));
    if (method.id === "seed_powder") return Math.max(1, Math.ceil(count / 18));
    if (method.id === "ghee") return Math.max(1, Math.ceil(count / 12));
    if (method.id === "dried_roti") return Math.max(1, Math.ceil(count / 10));
    if (method.id === "dal_papad") return Math.max(1, Math.ceil(count / 12));
    return Math.max(1, Math.ceil(count / 8));
}

function preservationFor(parsed, guests, safety) {
    var inputs = applicableInputs(parsed);
    var result = [];
    for (var i = 0; i < preservationMethods.length; ++i) {
        var method = preservationMethods[i];
        if (!methodFits(method, inputs)) continue;
        var blockers = safetyBlockers(method, safety);
        result.push({
            id: method.id,
            name: method.name,
            days: method.days,
            daysLabel: method.daysLabel,
            input: method.input,
            gate: method.gate,
            unitLabel: method.unitLabel,
            steps: method.steps,
            caveat: method.caveat,
            allowed: blockers.length === 0,
            blockers: blockers,
            jars: jarsFor(method, guests),
            label: method.name + " · " + method.daysLabel
        });
    }
    return result;
}

function batchCode(seed) {
    var value = hash32(seed);
    var alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    var out = "";
    for (var i = 0; i < 5; ++i) {
        out = alphabet.charAt(value % alphabet.length) + out;
        value = Math.floor(value / alphabet.length) + 7;
    }
    return "DHN-K-" + out;
}

function memorabiliaFor(parsed, guests, safety, preserves, options) {
    var allowed = [];
    for (var i = 0; i < preserves.length; ++i) {
        if (preserves[i].allowed && preserves[i].days >= 21) allowed.push(preserves[i]);
    }
    if (!allowed.length) return null;
    var now = options && options.now ? Number(options.now) : Date.now();
    var madeOn = new Date(now);
    var dateText = madeOn.getFullYear() + "-" + (madeOn.getMonth() + 1) + "-" + madeOn.getDate();
    allowed.sort(function (a, b) { return b.days - a.days; });
    var primary = allowed[0];
    var seed = (options && options.menuText ? options.menuText : "") + "|" + guests + "|" + primary.id + "|" + dateText;
    var allergen = "";
    for (var d = 0; d < parsed.dishes.length; ++d) {
        var dish = dishById(parsed.dishes[d].id);
        if (!dish) continue;
        if (dish.perHead.doodh || dish.perHead.ghee) allergen = "milk";
    }
    return {
        batchCode: batchCode(seed),
        madeOn: dateText,
        method: primary.name,
        shelfLife: primary.daysLabel,
        jars: primary.jars,
        notForSale: true,
        labelLines: [
            "DHUN COMMONS · KITCHEN BATCH",
            primary.name,
            "Made " + dateText + " · best within " + primary.daysLabel,
            primary.gate === "cooked" ? "Keep refrigerated" : "Keep cool and dry",
            allergen ? "Contains: " + allergen : "Check allergens before serving",
            "GUEST MEMORABILIA · NOT FOR SALE"
        ],
        note: "Label every jar with the batch code. Give jars only from a batch you have checked, and never sell them."
    };
}

function emptyPlan(reason) {
    return {
        ok: false,
        reason: reason,
        guests: 0,
        dishes: [],
        lines: [],
        groups: [],
        waste: [],
        zeroWaste: [],
        natives: [],
        preserves: [],
        memorabilia: null,
        totals: { cost: 0, costInr: 0, coverage: 0, lines: 0, covered: 0, shortfall: 0, requiredKg: 0, coveredKg: 0 },
        notes: []
    };
}

function buildPlan(state, options) {
    var opts = options || {};
    var parsed = opts.parsed || parseMenu(opts.menuText);
    if (!parsed.matched) return emptyPlan("No dish or ingredient was recognised. Type the menu lines, or load a sample menu.");
    var guests = clampInt(opts.guests, 1, 500);
    var month = clampInt(opts.month, 1, 12);
    var requirements = requirementsFor(parsed, guests);
    var lines = [];
    for (var i = 0; i < requirements.length; ++i) {
        var line = buildSourcingLine(state, requirements[i], month);
        if (line) lines.push(line);
    }
    if (!lines.length) return emptyPlan("The dish names were recognised, but they did not map to a farm ingredient.");

    var cost = 0;
    var marketCost = 0;
    var plotCost = 0;
    var covered = 0;
    var shortfall = 0;
    var plotLines = 0;
    var requiredKg = 0;
    var coveredKg = 0;
    for (var k = 0; k < lines.length; ++k) {
        cost += lines[k].cost;
        if (lines[k].estimated) plotCost += lines[k].cost;
        else marketCost += lines[k].cost;
        requiredKg += lines[k].need * unitWeight(lines[k].unit) / 1000;
        coveredKg += Math.min(lines[k].need, lines[k].stock) * unitWeight(lines[k].unit) / 1000;
        if (lines[k].status === "covered") covered += 1;
        if (lines[k].status === "plot") plotLines += 1;
        if (lines[k].shortfall > 0) shortfall += 1;
    }

    var preserves = preservationFor(parsed, guests, opts.safety || {});
    var allowedPreserves = [];
    for (var p = 0; p < preserves.length; ++p) if (preserves[p].allowed) allowedPreserves.push(preserves[p]);

    var plan = {
        ok: true,
        reason: "",
        guests: guests,
        month: month,
        season: seasonForMonth(month),
        parsed: parsed,
        dishes: parsed.dishes,
        extras: parsed.extras,
        unmatched: parsed.unmatched,
        lines: lines,
        groups: groupByZone(lines),
        waste: wasteFor(lines),
        zeroWaste: zeroWasteFor(parsed, lines),
        natives: nativesFor(parsed, lines, month),
        preserves: preserves,
        allowedPreserves: allowedPreserves,
        longLifePreserves: allowedPreserves.filter(function (item) { return item.days >= 21; }),
        memorabilia: memorabiliaFor(parsed, guests, opts.safety || {}, preserves, opts),
        totals: {
            cost: cost,
            costInr: Logic.formatINR(cost),
            marketCost: marketCost,
            marketCostInr: Logic.formatINR(marketCost),
            plotCost: plotCost,
            plotCostInr: Logic.formatINR(plotCost),
            coverage: requirements.length ? Math.round((covered / requirements.length) * 100) : 0,
            lines: lines.length,
            covered: covered,
            shortfall: shortfall,
            plotLines: plotLines,
            requiredKg: Math.round(requiredKg * 100) / 100,
            coveredKg: Math.round(coveredKg * 100) / 100
        },
        notes: [
            "Quantities are planning estimates, not a recipe or a nutrition prescription.",
            "Stock and prices come from the seeded Market offers. They are local rehearsal data, not live farmer inventory.",
            "Only jars from a checked batch are labelled; memorabilia is not for sale."
        ]
    };
    return plan;
}

function parseModelReply(content) {
    var text = String(content === undefined || content === null ? "" : content).trim();
    if (!text) return { ok: false, error: "The model returned an empty reply.", dishes: [], extras: [], notes: [] };
    text = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
    var start = text.indexOf("{");
    var end = text.lastIndexOf("}");
    if (start === -1 || end === -1 || end <= start)
        return { ok: false, error: "The model reply did not contain a JSON object.", dishes: [], extras: [], notes: [] };
    var payload;
    try {
        payload = JSON.parse(text.substring(start, end + 1));
    } catch (error) {
        return { ok: false, error: "The model reply was not valid JSON.", dishes: [], extras: [], notes: [] };
    }
    var rawDishes = payload.dishes || payload.menu || [];
    if (typeof rawDishes === "string") rawDishes = [rawDishes];
    var dishes = [];
    var extras = [];
    var unmatched = [];
    var seen = {};
    for (var i = 0; i < rawDishes.length; ++i) {
        var item = rawDishes[i];
        var name = typeof item === "string" ? item : (item && (item.name || item.title) ? (item.name || item.title) : "");
        if (!String(name).trim()) continue;
        var dish = dishForLine(name);
        if (dish) {
            if (!seen[dish.id]) {
                seen[dish.id] = true;
                dishes.push({ id: dish.id, name: dish.name, kind: dish.kind, matchedBy: name });
            }
            continue;
        }
        var found = false;
        for (var k = 0; k < Data.ingredients.length; ++k) {
            if (normalize(name).indexOf(normalize(Data.ingredients[k].name)) !== -1) {
                extras.push({ id: Data.ingredients[k].id, name: Data.ingredients[k].name, gramsPerHead: 100 });
                found = true;
                break;
            }
        }
        if (!found) unmatched.push(String(name));
    }
    var notes = [];
    if (Array.isArray(payload.notes)) notes = payload.notes;
    else if (payload.notes) notes = [String(payload.notes)];
    return {
        ok: true,
        dishes: dishes,
        extras: extras,
        unmatched: unmatched,
        notes: notes,
        servings: payload.servings ? clampInt(payload.servings, 1, 500) : 0,
        matched: dishes.length + extras.length
    };
}

function modelReplyToText(reply) {
    if (!reply || !reply.ok) return "";
    var lines = [];
    for (var i = 0; i < reply.dishes.length; ++i) lines.push(reply.dishes[i].name);
    for (var j = 0; j < reply.extras.length; ++j) lines.push(reply.extras[j].name);
    for (var k = 0; k < reply.unmatched.length; ++k) lines.push(reply.unmatched[k]);
    return lines.join("\n");
}

function localEndpointAllowed(endpoint) {
    var value = String(endpoint === undefined || endpoint === null ? "" : endpoint).trim();
    return /^https?:\/\/(127\.0\.0\.1|localhost|\[::1\])(:\d+)?(\/|$)/.test(value);
}

function chatCompletionsUrl(endpoint) {
    var base = String(endpoint || "").trim().replace(/\/+$/, "");
    if (/\/v1\/chat\/completions$/.test(base)) return base;
    if (/\/v1$/.test(base)) return base + "/chat/completions";
    return base + "/v1/chat/completions";
}

function modelsUrl(endpoint) {
    var base = String(endpoint || "").trim().replace(/\/+$/, "");
    if (/\/v1\/chat\/completions$/.test(base)) return base.replace(/\/chat\/completions$/, "/models");
    if (/\/v1$/.test(base)) return base + "/models";
    return base + "/v1/models";
}

var monthRoutes = {
    rabi: {
        dishes: ["bajra_roti", "moth_dal", "sarson_saag", "gajar_halwa"],
        note: "Rabi season · millet bread, desert beans and mustard greens."
    },
    kharif: {
        dishes: ["jowar_bhakri", "bhindi_masala", "moth_dal", "anar_chaat"],
        note: "Kharif season · sorghum, okra and orchard fruit."
    },
    zaid: {
        dishes: ["mung_khichdi", "lauki_sabzi", "kheera_raita", "tarbooz_cooler"],
        note: "Zaid season · gourds, mung and melon coolers."
    }
};

var moodRoutes = [
    {
        id: "cold",
        words: ["cold", "winter", "chilly", "freezing", "rainy", "monsoon", "snow"],
        dishes: ["sarson_saag", "bajra_roti", "moth_dal", "gajar_halwa"],
        note: "Warming rabi plates: slow-cooked greens, millet bread and a ghee finish."
    },
    {
        id: "tired",
        words: ["tired", "exhausted", "drained", "low", "long day", "hungry", "weak"],
        dishes: ["mung_khichdi", "bajra_roti", "amla_murabba", "kheera_raita"],
        note: "Soft, slow-release plates for a long day. This is a menu suggestion, not a health claim."
    },
    {
        id: "hot",
        words: ["hot", "heat", "summer", "sweaty", "thirsty", "scorching"],
        dishes: ["tarbooz_cooler", "kheera_raita", "lauki_sabzi", "mung_khichdi"],
        note: "Cooling zaid plates built around gourds and pressed fruit."
    },
    {
        id: "light",
        words: ["light", "sick", "unwell", "stomach", "comfort", "digest", "gentle"],
        dishes: ["mung_khichdi", "lauki_sabzi", "kheera_raita"],
        note: "Plain, gentle cooking. No medical claim: if someone is ill, follow local medical advice."
    },
    {
        id: "festive",
        words: ["festive", "celebration", "party", "feast", "birthday", "guests", "visitors"],
        dishes: ["gajar_halwa", "besan_gatta", "chana_curry", "anar_chaat"],
        note: "A shared thali with a sweet, a dumpling and a fruit plate."
    },
    {
        id: "fresh",
        words: ["fresh", "green", "salad", "clean", "crisp"],
        dishes: ["mung_sprouts", "kheera_raita", "dhaniya_chutney", "palak_saag"],
        note: "Green plates with a fresh chutney and a sprouted pulse."
    }
];

function interpretPrompt(text, month) {
    var raw = String(text === undefined || text === null ? "" : text).trim();
    if (!raw)
        return { ok: false, error: "Type a dish, a mood or what you feel like eating." };

    var normalized = normalize(raw);
    var dishes = [];
    var seen = {};
    var kind = "";
    var note = "";

    var direct = dishForLine(raw);
    if (direct) {
        seen[direct.id] = true;
        dishes.push(direct);
        kind = "dish";
        note = "Read the dish name directly from your text.";
    }

    for (var r = 0; r < moodRoutes.length; ++r) {
        var route = moodRoutes[r];
        var hit = false;
        for (var w = 0; w < route.words.length; ++w) {
            if (normalized.indexOf(route.words[w]) !== -1) { hit = true; break; }
        }
        if (!hit) continue;
        for (var d = 0; d < route.dishes.length; ++d) {
            var dish = dishById(route.dishes[d]);
            if (dish && !seen[dish.id]) {
                seen[dish.id] = true;
                dishes.push(dish);
            }
        }
        if (!kind) { kind = "mood"; note = route.note; }
        break;
    }

    if (!dishes.length) {
        var season = seasonForMonth(month);
        var fallback = monthRoutes[season ? season.id : "rabi"] || monthRoutes.rabi;
        for (var f = 0; f < fallback.dishes.length; ++f) {
            var seasonal = dishById(fallback.dishes[f]);
            if (seasonal && !seen[seasonal.id]) {
                seen[seasonal.id] = true;
                dishes.push(seasonal);
            }
        }
        kind = "season";
        note = fallback.note + " No dish or mood keyword matched, so the seasonal thali was used.";
    }

    if (dishes.length > 5) dishes = dishes.slice(0, 5);
    var guestMatch = raw.match(/(\d{1,3})\s*(?:guests?|people|persons?|pax|heads?)/i);
    return {
        ok: true,
        kind: kind,
        dishes: dishes,
        note: note,
        guests: guestMatch ? clampInt(guestMatch[1], 1, 500) : 0,
        text: dishes.map(function (item) { return item.name; }).join("\n")
    };
}

function buildPromptPlan(state, options) {
    var opts = options || {};
    var interpreted = interpretPrompt(opts.promptText, opts.month);
    if (!interpreted.ok) return emptyPlan(interpreted.error);
    var plan = buildPlan(state, {
        guests: opts.guests,
        month: opts.month,
        menuText: interpreted.text,
        safety: opts.safety,
        now: opts.now
    });
    if (plan.ok) {
        plan.prompt = {
            text: String(opts.promptText || ""),
            kind: interpreted.kind,
            note: interpreted.note,
            dishes: interpreted.dishes.map(function (item) { return item.name; }),
            suggestedGuests: interpreted.guests
        };
        plan.notes = [interpreted.note].concat(plan.notes);
    }
    return plan;
}

function zeroWasteFor(parsed, lines) {
    var kinds = {};
    var ids = {};
    for (var d = 0; d < parsed.dishes.length; ++d) {
        var dish = dishById(parsed.dishes[d].id);
        if (!dish) continue;
        kinds[dish.kind] = true;
        var keys = Object.keys(dish.perHead);
        for (var k = 0; k < keys.length; ++k) ids[keys[k]] = true;
    }
    var steps = [];
    if (kinds.veg) {
        steps.push({
            title: "Cook the whole vegetable",
            detail: "Wash stems and tender leaves into the same pot. Keep tougher peels and roots separate for stock or compost; do not put soiled trim back on a serving plate."
        });
    }
    if (kinds.dal || kinds.grain) {
        steps.push({
            title: "Keep the cooking liquid",
            detail: "Use measured soaking water in the pot and loosen the dal with it. Cool and refrigerate any surplus within two hours; reheat only once."
        });
    }
    if (kinds.bread) {
        steps.push({
            title: "Plan the last roti",
            detail: "Cook to the guest count, then dry any untouched roti for a crisp snack or feed it to livestock. Cooked bread that reached a plate is not preserved."
        });
    }
    if (ids.doodh) {
        steps.push({
            title: "Use the whey",
            detail: "Whey from curd or paneer can go into dough or dal the same day. Keep it cold and discard it if it smells sour."
        });
    }
    if (ids.nimbu) {
        steps.push({
            title: "Salt the citrus peel",
            detail: "Press clean lime peel with salt for a small condiment jar. Keep it labelled and refrigerated; do not claim a long shelf life without a tested method."
        });
    }
    if (!steps.length) {
        steps.push({
            title: "Route trim by destination",
            detail: "Keep clean trim for stock, send soiled trim to compost and keep anything that touched a plate out of preservation."
        });
    }
    steps.push({
        title: "Close the loop",
        detail: "Count what came back on plates, log it, and reduce the next purchase by that amount. Compost what cannot be eaten safely."
    });
    return steps;
}
