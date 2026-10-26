.pragma library

var site = {
    name: "Dhun",
    place: "Chak Gulabpura, Jaipur",
    latitude: 26.711302,
    longitude: 75.5901325,
    acres: 500,
    satellite: "qml/assets/dhun-satellite.jpg"
};

var monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
];

var monthShort = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

var zones = [
    {
        id: "farms",
        name: "Farms & Market Garden",
        short: "Farms",
        color: "#E0B25C",
        latitude: 26.7088,
        longitude: 75.5868,
        description: "Grain, pulse and vegetable beds worked with permaculture and precision irrigation."
    },
    {
        id: "orchard",
        name: "Orchards & Groves",
        short: "Orchards",
        color: "#7FB069",
        latitude: 26.7122,
        longitude: 75.5906,
        description: "Fruit trees and shade groves at the productive edge of the 300,000-tree bioreserve."
    },
    {
        id: "kitchen",
        name: "Kitchen Garden",
        short: "Kitchen",
        color: "#D97A52",
        latitude: 26.7143,
        longitude: 75.5936,
        description: "Herbs and specialist greens grown steps from the Culinary Lab."
    },
    {
        id: "dairy",
        name: "Dairy & Poultry",
        short: "Dairy",
        color: "#8FA6B2",
        latitude: 26.7077,
        longitude: 75.5958,
        description: "Native cattle and poultry on pasture and fodder, feeding the soil and the kitchen."
    }
];

var seasons = [
    {
        id: "kharif",
        name: "Kharif",
        months: [7, 8, 9, 10],
        window: "Jul — Oct",
        tagline: "Monsoon harvest"
    },
    {
        id: "rabi",
        name: "Rabi",
        months: [11, 12, 1, 2, 3],
        window: "Nov — Mar",
        tagline: "Cool-season harvest"
    },
    {
        id: "zaid",
        name: "Zaid",
        months: [4, 5, 6],
        window: "Apr — Jun",
        tagline: "Dry-season garden"
    }
];

var ingredients = [
    {
        id: "bajra", name: "Bajra", local: "Pearl millet", botanical: "Pennisetum glaucum",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Grain",
        seasons: ["kharif"], months: [9, 10], yearRound: false,
        unit: "kg", price: 55, harvestLabel: "Sep — Oct",
        blurb: "Rain-fed pearl millet with a deep, nutty finish — the backbone of a Rajasthani thali."
    },
    {
        id: "jowar", name: "Jowar", local: "Sorghum", botanical: "Sorghum bicolor",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Grain",
        seasons: ["kharif"], months: [10, 11], yearRound: false,
        unit: "kg", price: 65, harvestLabel: "Oct — Nov",
        blurb: "Soft, climate-resilient sorghum for bhakri, khichdi and cool-morning porridge."
    },
    {
        id: "moth", name: "Moth", local: "Moth bean", botanical: "Vigna aconitifolia",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Pulse",
        seasons: ["kharif"], months: [9, 10], yearRound: false,
        unit: "kg", price: 120, harvestLabel: "Sep — Oct",
        blurb: "Tiny desert beans that cook quickly and hold a firm, earthy bite."
    },
    {
        id: "mung", name: "Mung", local: "Green gram", botanical: "Vigna radiata",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Pulse",
        seasons: ["kharif", "zaid"], months: [5, 6, 9, 10], yearRound: false,
        unit: "kg", price: 140, harvestLabel: "May — Jun · Sep — Oct",
        blurb: "Bright green gram for dal, sprouts and the lightest summer khichdi."
    },
    {
        id: "guar", name: "Guar", local: "Cluster bean", botanical: "Cyamopsis tetragonoloba",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Pulse",
        seasons: ["kharif"], months: [9, 10, 11], yearRound: false,
        unit: "kg", price: 80, harvestLabel: "Sep — Nov",
        blurb: "Cluster beans picked young, with a pleasant bitterness and a clean snap."
    },
    {
        id: "chana", name: "Chana", local: "Desi chickpea", botanical: "Cicer arietinum",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Pulse",
        seasons: ["rabi"], months: [2, 3], yearRound: false,
        unit: "kg", price: 95, harvestLabel: "Feb — Mar",
        blurb: "Desi chickpeas for slow curries and besan milled fresh at the farm."
    },
    {
        id: "gehun", name: "Gehun", local: "Wheat", botanical: "Triticum aestivum",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Grain",
        seasons: ["rabi"], months: [3, 4], yearRound: false,
        unit: "kg", price: 45, harvestLabel: "Mar — Apr",
        blurb: "Stone-milled wheat from the cool-season plots, sweet and faintly grassy."
    },
    {
        id: "sarson", name: "Sarson", local: "Mustard greens", botanical: "Brassica juncea",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Vegetable",
        seasons: ["rabi"], months: [11, 12, 1, 2], yearRound: false,
        unit: "bunch", price: 35, harvestLabel: "Nov — Feb",
        blurb: "Peppery mustard greens for saag, best after the first cold nights."
    },
    {
        id: "palak", name: "Palak", local: "Spinach", botanical: "Spinacia oleracea",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Vegetable",
        seasons: ["rabi"], months: [11, 12, 1, 2], yearRound: false,
        unit: "bunch", price: 30, harvestLabel: "Nov — Feb",
        blurb: "Tender spinach leaves, delicate enough for a warm winter salad."
    },
    {
        id: "methi", name: "Methi", local: "Fenugreek", botanical: "Trigonella foenum-graecum",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Vegetable",
        seasons: ["rabi"], months: [11, 12, 1, 2], yearRound: false,
        unit: "bunch", price: 30, harvestLabel: "Nov — Feb",
        blurb: "Aromatic fenugreek with a gentle bitter edge for parathas and dals."
    },
    {
        id: "bhindi", name: "Bhindi", local: "Okra", botanical: "Abelmoschus esculentus",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Vegetable",
        seasons: ["kharif"], months: [8, 9, 10], yearRound: false,
        unit: "kg", price: 70, harvestLabel: "Aug — Oct",
        blurb: "Monsoon okra picked small, glossy and snappy."
    },
    {
        id: "lauki", name: "Lauki", local: "Bottle gourd", botanical: "Lagenaria siceraria",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Vegetable",
        seasons: ["kharif", "zaid"], months: [4, 5, 6, 7, 8, 9], yearRound: false,
        unit: "kg", price: 35, harvestLabel: "Apr — Sep",
        blurb: "Cool bottle gourd for light curries, raita and long summer afternoons."
    },
    {
        id: "petha", name: "Petha", local: "Ash gourd", botanical: "Benincasa hispida",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Vegetable",
        seasons: ["kharif"], months: [9, 10, 11], yearRound: false,
        unit: "kg", price: 35, harvestLabel: "Sep — Nov",
        blurb: "Ash gourd with dense white flesh, slow-cooked into petha or a cooling sabzi."
    },
    {
        id: "tamatar", name: "Tamatar", local: "Tomato", botanical: "Solanum lycopersicum",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Vegetable",
        seasons: ["rabi"], months: [1, 2, 3], yearRound: false,
        unit: "kg", price: 50, harvestLabel: "Jan — Mar",
        blurb: "Sun-ripened tomatoes with enough acidity to carry a winter rasam."
    },
    {
        id: "baingan", name: "Baingan", local: "Brinjal", botanical: "Solanum melongena",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Vegetable",
        seasons: ["rabi"], months: [12, 1, 2, 3], yearRound: false,
        unit: "kg", price: 45, harvestLabel: "Dec — Mar",
        blurb: "Small brinjals with few seeds, built for smoky bharta."
    },
    {
        id: "gajar", name: "Gajar", local: "Carrot", botanical: "Daucus carota",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Vegetable",
        seasons: ["rabi"], months: [12, 1, 2], yearRound: false,
        unit: "kg", price: 40, harvestLabel: "Dec — Feb",
        blurb: "Sweet winter carrots, good raw, roasted or in gajar halwa."
    },
    {
        id: "matar", name: "Matar", local: "Garden peas", botanical: "Pisum sativum",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Vegetable",
        seasons: ["rabi"], months: [1, 2, 3], yearRound: false,
        unit: "kg", price: 100, harvestLabel: "Jan — Mar",
        blurb: "Sweet garden peas picked at dawn, best within a day."
    },
    {
        id: "tarbooz", name: "Tarbooz", local: "Watermelon", botanical: "Citrullus lanatus",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Fruit",
        seasons: ["zaid"], months: [4, 5, 6], yearRound: false,
        unit: "kg", price: 25, harvestLabel: "Apr — Jun",
        blurb: "Dry-season watermelon, irrigated sparingly and picked at full sugar."
    },
    {
        id: "kharbooja", name: "Kharbooja", local: "Muskmelon", botanical: "Cucumis melo",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Fruit",
        seasons: ["zaid"], months: [4, 5, 6], yearRound: false,
        unit: "kg", price: 40, harvestLabel: "Apr — Jun",
        blurb: "Perfumed muskmelon for slow breakfasts and cold soups."
    },
    {
        id: "kheera", name: "Kheera", local: "Cucumber", botanical: "Cucumis sativus",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Vegetable",
        seasons: ["zaid", "kharif"], months: [3, 4, 5, 6], yearRound: false,
        unit: "kg", price: 40, harvestLabel: "Mar — Jun",
        blurb: "Crisp cucumbers from the sand-mulched beds."
    },
    {
        id: "til", name: "Til", local: "Sesame", botanical: "Sesamum indicum",
        zone: "farms", zoneName: "Farms & Market Garden", category: "Seed",
        seasons: ["kharif"], months: [9, 10], yearRound: false,
        unit: "kg", price: 220, harvestLabel: "Sep — Oct",
        blurb: "Sesame seeds for toasted chutneys, til laddoo and cold-pressed oil."
    },
    {
        id: "amla", name: "Amla", local: "Indian gooseberry", botanical: "Phyllanthus emblica",
        zone: "orchard", zoneName: "Orchards & Groves", category: "Fruit",
        seasons: ["rabi"], months: [11, 12, 1], yearRound: false,
        unit: "kg", price: 70, harvestLabel: "Nov — Jan",
        blurb: "Tart gooseberry for murabba, juice and the winter pantry."
    },
    {
        id: "ber", name: "Ber", local: "Indian jujube", botanical: "Ziziphus mauritiana",
        zone: "orchard", zoneName: "Orchards & Groves", category: "Fruit",
        seasons: ["rabi"], months: [12, 1, 2, 3], yearRound: false,
        unit: "kg", price: 80, harvestLabel: "Dec — Mar",
        blurb: "Small jujubes with an apple-like crunch and a wild edge."
    },
    {
        id: "amrud", name: "Amrud", local: "Guava", botanical: "Psidium guajava",
        zone: "orchard", zoneName: "Orchards & Groves", category: "Fruit",
        seasons: ["rabi"], months: [11, 12, 1, 2], yearRound: false,
        unit: "kg", price: 70, harvestLabel: "Nov — Feb",
        blurb: "Fragrant guava from the groves, at its best when the nights turn cool."
    },
    {
        id: "anar", name: "Anar", local: "Pomegranate", botanical: "Punica granatum",
        zone: "orchard", zoneName: "Orchards & Groves", category: "Fruit",
        seasons: ["kharif"], months: [8, 9, 10, 11], yearRound: false,
        unit: "kg", price: 160, harvestLabel: "Aug — Nov",
        blurb: "Deep-red pomegranate arils with a bright, mineral finish."
    },
    {
        id: "nimbu", name: "Nimbu", local: "Lime", botanical: "Citrus limon",
        zone: "orchard", zoneName: "Orchards & Groves", category: "Fruit",
        seasons: ["kharif", "rabi", "zaid"], months: [1,2,3,4,5,6,7,8,9,10,11,12], yearRound: true,
        unit: "kg", price: 60, harvestLabel: "Year-round",
        blurb: "Thin-skinned limes for endless nimbu pani and preserved pickle."
    },
    {
        id: "aam", name: "Aam", local: "Mango", botanical: "Mangifera indica",
        zone: "orchard", zoneName: "Orchards & Groves", category: "Fruit",
        seasons: ["zaid"], months: [5, 6], yearRound: false,
        unit: "kg", price: 140, harvestLabel: "May — Jun",
        blurb: "Summer mangoes from the orchard edge, ripened without a cold chain."
    },
    {
        id: "dhaniya", name: "Dhaniya", local: "Coriander", botanical: "Coriandrum sativum",
        zone: "kitchen", zoneName: "Kitchen Garden", category: "Herb",
        seasons: ["rabi"], months: [11, 12, 1, 2, 3], yearRound: false,
        unit: "bunch", price: 25, harvestLabel: "Nov — Mar",
        blurb: "Fragrant coriander, cut fresh each morning for the Culinary Lab."
    },
    {
        id: "pudina", name: "Pudina", local: "Mint", botanical: "Mentha spicata",
        zone: "kitchen", zoneName: "Kitchen Garden", category: "Herb",
        seasons: ["kharif", "rabi", "zaid"], months: [1,2,3,4,5,6,7,8,9,10,11,12], yearRound: true,
        unit: "bunch", price: 25, harvestLabel: "Year-round",
        blurb: "Cool mint for chutneys, teas and the farm's cold buttermilk."
    },
    {
        id: "moringa", name: "Moringa", local: "Drumstick greens", botanical: "Moringa oleifera",
        zone: "kitchen", zoneName: "Kitchen Garden", category: "Herb",
        seasons: ["zaid", "kharif"], months: [4, 5, 6, 7, 8, 9], yearRound: false,
        unit: "bunch", price: 40, harvestLabel: "Apr — Sep",
        blurb: "Tender drumstick greens with a clean, mineral taste."
    },
    {
        id: "curry_patta", name: "Curry Patta", local: "Curry leaf", botanical: "Murraya koenigii",
        zone: "kitchen", zoneName: "Kitchen Garden", category: "Herb",
        seasons: ["kharif", "rabi", "zaid"], months: [1,2,3,4,5,6,7,8,9,10,11,12], yearRound: true,
        unit: "bunch", price: 20, harvestLabel: "Year-round",
        blurb: "Curry leaves for tempering — best used the day they are picked."
    },
    {
        id: "microgreens", name: "Microgreens", local: "Kitchen trays", botanical: "",
        zone: "kitchen", zoneName: "Kitchen Garden", category: "Herb",
        seasons: ["kharif", "rabi", "zaid"], months: [1,2,3,4,5,6,7,8,9,10,11,12], yearRound: true,
        unit: "box", price: 120, harvestLabel: "Year-round",
        blurb: "A rotating tray of pea, radish and mustard shoots for the kitchen."
    },
    {
        id: "doodh", name: "Doodh", local: "Fresh milk", botanical: "",
        zone: "dairy", zoneName: "Dairy & Poultry", category: "Dairy",
        seasons: ["kharif", "rabi", "zaid"], months: [1,2,3,4,5,6,7,8,9,10,11,12], yearRound: true,
        unit: "litre", price: 80, harvestLabel: "Year-round",
        blurb: "Milk from the native herd, collected the same morning."
    },
    {
        id: "ghee", name: "Ghee", local: "Cultured ghee", botanical: "",
        zone: "dairy", zoneName: "Dairy & Poultry", category: "Dairy",
        seasons: ["kharif", "rabi", "zaid"], months: [1,2,3,4,5,6,7,8,9,10,11,12], yearRound: true,
        unit: "jar", price: 650, harvestLabel: "Year-round",
        blurb: "Slow-cultured, hand-churned ghee from the farm dairy."
    },
    {
        id: "ande", name: "Ande", local: "Country eggs", botanical: "",
        zone: "dairy", zoneName: "Dairy & Poultry", category: "Poultry",
        seasons: ["kharif", "rabi", "zaid"], months: [1,2,3,4,5,6,7,8,9,10,11,12], yearRound: true,
        unit: "dozen", price: 180, harvestLabel: "Year-round",
        blurb: "Free-ranging country eggs with deep amber yolks."
    }
];

var producePhotos = {
    bajra: "bajra", jowar: "jowar", gehun: "gehun", til: "til",
    moth: "moth", mung: "mung", guar: "guar", chana: "chana",
    sarson: "sarson", palak: "palak", methi: "methi",
    bhindi: "bhindi", lauki: "lauki", petha: "petha",
    tamatar: "tamatar", baingan: "baingan", gajar: "gajar",
    matar: "matar", kheera: "kheera",
    tarbooz: "tarbooz", kharbooja: "kharbooja",
    amla: "amla", ber: "ber", amrud: "amrud", anar: "anar",
    nimbu: "nimbu", aam: "aam",
    dhaniya: "dhaniya", pudina: "pudina", moringa: "moringa",
    curry_patta: "curry_patta", microgreens: "microgreens",
    doodh: "rathi_cow", ghee: "ghee", ande: "eggs"
};

// Reference species of the Dhun landscape. Photos are Wikimedia Commons
// records of the species, not photographs of Dhun's own fields; full author
// and licence data is in docs/NATIVE-SPECIES.md.
var nativeSpecies = [
    {
        id: "khejri", name: "Khejri", local: "Prosopis cineraria",
        kind: "Tree \u00B7 foraged pods", photo: "khejri",
        note: "Rajasthan's state tree. Deep roots and nitrogen-fixing shade shelter dryland crops; its green pods are harvested as sangri.",
        credit: "Mulkh Singh / CC BY-SA 4.0"
    },
    {
        id: "sangri", name: "Sangri", local: "Prosopis cineraria pod",
        kind: "Foraged produce", photo: "sangri",
        note: "Unripe khejri pods, dried and stored for curries. Harvested from marker trees with retention left for seed and fodder.",
        credit: "LRBurdak / CC BY-SA 3.0"
    },
    {
        id: "ker", name: "Ker", local: "Capparis decidua",
        kind: "Thorn scrub \u00B7 foraged bud", photo: "ker",
        note: "Leafless thorn scrub of the Thar edge. Its buds and small fruit are pickled or dried as ker/teent.",
        credit: "Kingshuk Mondal / CC BY 4.0"
    },
    {
        id: "kumatiya", name: "Kumatiya", local: "Senegalia senegal",
        kind: "Tree \u00B7 gum and pod", photo: "kumatiya",
        note: "Gum-arabic acacia. Pods and gum are gathered in the dry season; the tree also fixes nitrogen and checks erosion.",
        credit: "WikiPanti / CC BY-SA 4.0"
    },
    {
        id: "gunda", name: "Gunda / Lasoda", local: "Cordia dichotoma",
        kind: "Tree \u00B7 foraged fruit", photo: "gunda",
        note: "Shade tree whose sticky green fruit is pickled or cooked. A common boundary and homestead tree in the Jaipur belt.",
        credit: "Steve Fitzgerald / CC BY-SA 4.0"
    },
    {
        id: "amla", name: "Amla", local: "Phyllanthus emblica",
        kind: "Native fruit", photo: "amla",
        note: "Astringent, vitamin-C-rich fruit used fresh, dried and in preserves. The Pushkar belt is a documented growing area.",
        credit: "Ji-Elle / CC BY-SA 4.0"
    },
    {
        id: "ber", name: "Ber", local: "Ziziphus mauritiana",
        kind: "Native fruit", photo: "ber",
        note: "Hardy dryland fruit. Thorny native stock is also used for grafting improved ber varieties.",
        credit: "Ethel Aardvark / CC BY 3.0"
    },
    {
        id: "moringa", name: "Moringa", local: "Moringa oleifera",
        kind: "Tree \u00B7 leaf and pod", photo: "moringa",
        note: "Drumstick tree. Leaves and pods are eaten; the tree leafs through the hot, dry months when other greens fail.",
        credit: "Mokkie / CC BY-SA 3.0"
    },
    {
        id: "rathi_cow", name: "Rathi cow", local: "Bos indicus",
        kind: "Livestock \u00B7 native breed", photo: "rathi_cow",
        note: "Rajasthan dairy breed from the Bikaner\u2013Alwar belt, kept for milk and ghee under low-input dryland conditions.",
        credit: "Pavanaja / CC BY-SA 3.0"
    },
    {
        id: "sirohi_goat", name: "Sirohi goat", local: "Capra hircus",
        kind: "Livestock \u00B7 native breed", photo: "sirohi_goat",
        note: "Dual-purpose breed from Sirohi district, valued for browsing on scrub and for milk and meat.",
        credit: "Akbarkq / CC BY-SA 3.0"
    },
    {
        id: "desi_hen", name: "Desi poultry", local: "Gallus gallus domesticus",
        kind: "Livestock \u00B7 country poultry", photo: "desi_hen",
        note: "Free-ranging country hens supply eggs and pest control. The photograph is a species reference, not a Dhun flock.",
        credit: "Andrei Niemim\u00E4ki / CC BY-SA 2.0"
    }
];

var growers = [
    {
        id: "dhun-field", name: "Dhun Field Unit", short: "Dhun field",
        role: "dhun", village: "Chak Gulabpura",
        latitude: 26.7096, longitude: 75.5879,
        note: "Coordinates the annual beds, the seed lot and the field crew."
    },
    {
        id: "khejri", name: "Khejri Mandal", short: "Khejri",
        role: "steward", village: "Gulabpura",
        latitude: 26.71284, longitude: 75.59033,
        note: "Orchard crew. Selective harvest, 20% fruit retention and marker-tree logs."
    },
    {
        id: "bhawani", name: "Bhawani Women's Collective", short: "Bhawani",
        role: "steward", village: "Chak Gulabpura",
        latitude: 26.71452, longitude: 75.59304,
        note: "Kitchen garden, nursery trays and the daily herb cut for the Culinary Lab."
    },
    {
        id: "gulabpura-dairy", name: "Gulabpura Dairy", short: "Dairy",
        role: "steward", village: "Gulabpura",
        latitude: 26.70824, longitude: 75.59509,
        note: "Native herd, fodder rotation and the morning milk run."
    },
    {
        id: "shekhawati-seed", name: "Shekhawati Seed Co-op", short: "Seed co-op",
        role: "steward", village: "Shekhawati",
        latitude: 26.70772, longitude: 75.58553,
        note: "Certified seed lots, grain cleaning and the community seed bank."
    },
    {
        id: "bioreserve-nursery", name: "Bioreserve Nursery", short: "Nursery",
        role: "dhun", village: "Chak Gulabpura",
        latitude: 26.71303, longitude: 75.59226,
        note: "Native saplings, orchard edge planting and pollinator strips."
    }
];

var activityTypes = [
    { id: "sowing", label: "Sowing", color: "#B9D567" },
    { id: "irrigation", label: "Irrigation", color: "#8FA6B2" },
    { id: "compost", label: "Compost", color: "#C76B47" },
    { id: "weeding", label: "Weeding", color: "#E0B25C" },
    { id: "harvest", label: "Harvest", color: "#D97A52" },
    { id: "pruning", label: "Pruning", color: "#7FB069" },
    { id: "scouting", label: "Scouting", color: "#2B4D38" },
    { id: "mulch", label: "Mulching", color: "#9B6D22" },
    { id: "soil", label: "Soil test", color: "#8F452A" },
    { id: "delivery", label: "Handover", color: "#6D7B70" },
    { id: "review", label: "Review", color: "#E0B25C" }
];

var growerPools = {
    farms: ["dhun-field", "shekhawati-seed"],
    orchard: ["khejri", "bioreserve-nursery"],
    kitchen: ["bhawani"],
    dairy: ["gulabpura-dairy"]
};

function hash32(text) {
    var h = 0x811c9dc5;
    var value = String(text);
    for (var i = 0; i < value.length; ++i) {
        h ^= value.charCodeAt(i);
        h = Math.imul(h, 0x01000193) >>> 0;
    }
    return h >>> 0;
}

function zoneById(id) {
    for (var i = 0; i < zones.length; ++i) {
        if (zones[i].id === id) return zones[i];
    }
    return null;
}

function growerById(id) {
    for (var i = 0; i < growers.length; ++i) {
        if (growers[i].id === id) return growers[i];
    }
    return null;
}

function activityTypeById(id) {
    for (var i = 0; i < activityTypes.length; ++i) {
        if (activityTypes[i].id === id) return activityTypes[i];
    }
    return activityTypes[0];
}

function photoFor(ingredient) {
    var group = ingredient ? producePhotos[ingredient.id] : "";
    return group ? group : "vegetables";
}

function growerFor(ingredient) {
    if (!ingredient) return growers[0];
    var pool = growerPools[ingredient.zone] || growerPools.farms;
    return growerById(pool[hash32(ingredient.id) % pool.length]) || growers[0];
}

function plotFor(ingredient) {
    if (!ingredient) return { latitude: site.latitude, longitude: site.longitude };
    var zone = zoneById(ingredient.zone);
    var h = hash32(ingredient.id);
    var angle = ((h % 360) / 180) * Math.PI;
    var radius = 0.0026 + ((h >> 9) % 140) / 100000;
    return {
        latitude: zone.latitude + Math.sin(angle) * radius * 0.82,
        longitude: zone.longitude + Math.cos(angle) * radius
    };
}

function ingredientById(id) {
    for (var i = 0; i < ingredients.length; ++i) {
        if (ingredients[i].id === id) return ingredients[i];
    }
    return null;
}

function calendarCells(year, month) {
    var first = new Date(year, month, 1);
    var offset = (first.getDay() + 6) % 7;
    var start = new Date(year, month, 1 - offset);
    var cells = [];
    for (var i = 0; i < 42; ++i) {
        var date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
        cells.push({
            day: date.getDate(),
            month: date.getMonth(),
            year: date.getFullYear(),
            inMonth: date.getMonth() === month,
            timestamp: date.getTime()
        });
    }
    return cells;
}

function dateKey(timestamp) {
    var date = new Date(Number(timestamp) || Date.now());
    return date.getFullYear() + "-" + (date.getMonth() + 1) + "-" + date.getDate();
}

function formatFieldDate(timestamp, now) {
    var date = new Date(Number(timestamp) || Date.now());
    var today = new Date(Number(now) || Date.now());
    if (dateKey(date.getTime()) === dateKey(today.getTime())) return "Today";
    var tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
    if (dateKey(date.getTime()) === dateKey(tomorrow.getTime())) return "Tomorrow";
    return monthShort[date.getMonth()] + " " + date.getDate() + " · " +
            (date.getHours() < 10 ? "0" : "") + date.getHours() + ":" +
            (date.getMinutes() < 10 ? "0" : "") + date.getMinutes();
}

function seasonById(id) {
    for (var i = 0; i < seasons.length; ++i) {
        if (seasons[i].id === id) return seasons[i];
    }
    return null;
}

function seasonForMonth(month) {
    if (month >= 7 && month <= 10) return seasonById("kharif");
    if (month >= 11 || month <= 3) return seasonById("rabi");
    return seasonById("zaid");
}

function seasonLabelForIngredient(ingredient) {
    if (ingredient.yearRound) return "Year-round";
    var labels = [];
    for (var i = 0; i < ingredient.seasons.length; ++i) {
        var s = seasonById(ingredient.seasons[i]);
        if (s) labels.push(s.name);
    }
    return labels.join(" · ");
}

function isInSeason(ingredient, month) {
    if (ingredient.yearRound) return true;
    return ingredient.months.indexOf(month) !== -1;
}

function matchesFilter(ingredient, mode, month, seasonId) {
    if (mode === "all") return true;
    if (mode === "season") {
        return ingredient.yearRound || ingredient.seasons.indexOf(seasonId) !== -1;
    }
    return isInSeason(ingredient, month);
}

function pickupOptions(ingredient, now) {
    var options = [];
    var startMonth = now.getMonth() + 1;
    var startYear = now.getFullYear();
    for (var i = 0; i < 14 && options.length < 8; ++i) {
        var date = new Date(startYear, startMonth - 1 + i, 1);
        var month = date.getMonth() + 1;
        if (ingredient.yearRound || ingredient.months.indexOf(month) !== -1) {
            var season = seasonForMonth(month);
            options.push({
                value: String(date.getFullYear()) + "-" + (month < 10 ? "0" : "") + String(month),
                label: monthShort[month - 1] + " " + String(date.getFullYear()),
                short: monthShort[month - 1],
                month: month,
                year: date.getFullYear(),
                season: season ? season.name : ""
            });
        }
    }
    return options;
}

function formatINR(value) {
    var rounded = Math.round(Number(value) || 0);
    var sign = rounded < 0 ? "-" : "";
    var digits = String(Math.abs(rounded));
    if (digits.length <= 3) return "₹" + sign + digits;
    var last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    rest = rest.replace(/\B(?=(\d{2})+(?!\d))/g, ",");
    return "₹" + sign + rest + "," + last3;
}

function formatQuantity(value) {
    var number = Number(value) || 0;
    return number % 1 === 0 ? String(number) : number.toFixed(1);
}

function formatCoordinate(value, positive, negative) {
    return Math.abs(value).toFixed(4) + "° " + (value >= 0 ? positive : negative);
}

function bookingReference(seed) {
    var alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    var value = Math.abs(Math.floor(Number(seed) || 1));
    var out = "";
    for (var i = 0; i < 5; ++i) {
        out = alphabet.charAt(value % alphabet.length) + out;
        value = Math.floor(value / alphabet.length) + 7;
    }
    return "DH-" + out;
}
