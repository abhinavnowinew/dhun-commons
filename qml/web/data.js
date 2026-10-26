(function (root) {
    "use strict";

    var site = {
        name: "Dhun",
        place: "Chak Gulabpura, Jaipur",
        latitude: 26.711302,
        longitude: 75.5901325,
        acres: 500,
        satellite: "../assets/dhun-satellite.jpg",
        boundaryRadius: 760
    };

    var zones = [
        {
            id: "farms", name: "Farms & Market Garden", short: "Farms", color: "#E0B25C",
            latitude: 26.7088, longitude: 75.5868,
            description: "Grain, pulse and vegetable beds worked with permaculture and precision irrigation."
        },
        {
            id: "orchard", name: "Orchards & Groves", short: "Orchards", color: "#7FB069",
            latitude: 26.7122, longitude: 75.5906,
            description: "Fruit trees and shade groves at the productive edge of the bioreserve."
        },
        {
            id: "kitchen", name: "Kitchen Garden", short: "Kitchen", color: "#D97A52",
            latitude: 26.7143, longitude: 75.5936,
            description: "Herbs and specialist greens grown steps from the Culinary Lab."
        },
        {
            id: "dairy", name: "Dairy & Poultry", short: "Dairy", color: "#8FA6B2",
            latitude: 26.7077, longitude: 75.5958,
            description: "Native cattle and poultry on pasture and fodder, feeding the soil and the kitchen."
        }
    ];

    var growers = [
        {
            id: "dhun-field", name: "Dhun Field Unit", short: "Dhun field", role: "dhun",
            village: "Chak Gulabpura", latitude: 26.7096, longitude: 75.5879,
            note: "Coordinates the annual beds, the seed lot and the field crew."
        },
        {
            id: "khejri", name: "Khejri Mandal", short: "Khejri", role: "steward",
            village: "Gulabpura", latitude: 26.71284, longitude: 75.59033,
            note: "Orchard crew. Selective harvest, 20% fruit retention and marker-tree logs."
        },
        {
            id: "bhawani", name: "Bhawani Women's Collective", short: "Bhawani", role: "steward",
            village: "Chak Gulabpura", latitude: 26.71452, longitude: 75.59304,
            note: "Kitchen garden, nursery trays and the daily herb cut for the Culinary Lab."
        },
        {
            id: "gulabpura-dairy", name: "Gulabpura Dairy", short: "Dairy", role: "steward",
            village: "Gulabpura", latitude: 26.70824, longitude: 75.59509,
            note: "Native herd, fodder rotation and the morning milk run."
        },
        {
            id: "shekhawati-seed", name: "Shekhawati Seed Co-op", short: "Seed co-op", role: "steward",
            village: "Shekhawati", latitude: 26.70772, longitude: 75.58553,
            note: "Certified seed lots, grain cleaning and the community seed bank."
        },
        {
            id: "bioreserve-nursery", name: "Bioreserve Nursery", short: "Nursery", role: "dhun",
            village: "Chak Gulabpura", latitude: 26.71303, longitude: 75.59226,
            note: "Native saplings, orchard edge planting and pollinator strips."
        }
    ];

    var growerPools = {
        farms: ["dhun-field", "shekhawati-seed"],
        orchard: ["khejri", "bioreserve-nursery"],
        kitchen: ["bhawani"],
        dairy: ["gulabpura-dairy"]
    };

    var activityTypes = [
        { id: "sowing", label: "Sowing", color: "#B9D567", hint: "Seed, drill or transplant" },
        { id: "irrigation", label: "Irrigation", color: "#8FA6B2", hint: "Water, check dams, drip" },
        { id: "compost", label: "Compost", color: "#C76B47", hint: "Windrows, amendments" },
        { id: "weeding", label: "Weeding", color: "#E0B25C", hint: "Hand or mechanical" },
        { id: "harvest", label: "Harvest", color: "#D97A52", hint: "Picking and grading" },
        { id: "pruning", label: "Pruning", color: "#7FB069", hint: "Canopy and orchard care" },
        { id: "scouting", label: "Scouting", color: "#2B4D38", hint: "Pest, moisture, walk-through" },
        { id: "mulch", label: "Mulching", color: "#9B6D22", hint: "Straw, chop-and-drop" },
        { id: "soil", label: "Soil test", color: "#8F452A", hint: "Sampling and readings" },
        { id: "delivery", label: "Handover", color: "#6D7B70", hint: "Packing, weighing, handoff" },
        { id: "review", label: "Review", color: "#E0B25C", hint: "Covenant and treasury review" }
    ];

    var raw = [
        ["bajra", "Bajra", "Pearl millet", "Pennisetum glaucum", "Grain", "farms", 55, "kg", [9, 10], false, "grains", "Sep \u2014 Oct", "Rain-fed pearl millet with a deep, nutty finish \u2014 the backbone of a Rajasthani thali."],
        ["jowar", "Jowar", "Sorghum", "Sorghum bicolor", "Grain", "farms", 65, "kg", [10, 11], false, "grains", "Oct \u2014 Nov", "Soft, climate-resilient sorghum for bhakri, khichdi and cool-morning porridge."],
        ["moth", "Moth", "Moth bean", "Vigna aconitifolia", "Pulse", "farms", 120, "kg", [9, 10], false, "pulses", "Sep \u2014 Oct", "Tiny desert beans that cook quickly and hold a firm, earthy bite."],
        ["mung", "Mung", "Green gram", "Vigna radiata", "Pulse", "farms", 140, "kg", [5, 6, 9, 10], false, "pulses", "May \u2014 Jun \u00B7 Sep \u2014 Oct", "Bright green gram for dal, sprouts and the lightest summer khichdi."],
        ["guar", "Guar", "Cluster bean", "Cyamopsis tetragonoloba", "Pulse", "farms", 80, "kg", [9, 10, 11], false, "pulses", "Sep \u2014 Nov", "Cluster beans picked young, with a pleasant bitterness and a clean snap."],
        ["chana", "Chana", "Desi chickpea", "Cicer arietinum", "Pulse", "farms", 95, "kg", [2, 3], false, "pulses", "Feb \u2014 Mar", "Desi chickpeas for slow curries and besan milled fresh at the farm."],
        ["gehun", "Gehun", "Wheat", "Triticum aestivum", "Grain", "farms", 45, "kg", [3, 4], false, "grains", "Mar \u2014 Apr", "Stone-milled wheat from the cool-season plots, sweet and faintly grassy."],
        ["sarson", "Sarson", "Mustard greens", "Brassica juncea", "Vegetable", "farms", 35, "bunch", [11, 12, 1, 2], false, "greens", "Nov \u2014 Feb", "Peppery mustard greens for saag, best after the first cold nights."],
        ["palak", "Palak", "Spinach", "Spinacia oleracea", "Vegetable", "farms", 30, "bunch", [11, 12, 1, 2], false, "greens", "Nov \u2014 Feb", "Tender spinach leaves, delicate enough for a warm winter salad."],
        ["methi", "Methi", "Fenugreek", "Trigonella foenum-graecum", "Vegetable", "farms", 30, "bunch", [11, 12, 1, 2], false, "greens", "Nov \u2014 Feb", "Aromatic fenugreek with a gentle bitter edge for parathas and dals."],
        ["bhindi", "Bhindi", "Okra", "Abelmoschus esculentus", "Vegetable", "farms", 70, "kg", [8, 9, 10], false, "vegetables", "Aug \u2014 Oct", "Monsoon okra picked small, glossy and snappy."],
        ["lauki", "Lauki", "Bottle gourd", "Lagenaria siceraria", "Vegetable", "farms", 35, "kg", [4, 5, 6, 7, 8, 9], false, "vegetables", "Apr \u2014 Sep", "Cool bottle gourd for light curries, raita and long summer afternoons."],
        ["petha", "Petha", "Ash gourd", "Benincasa hispida", "Vegetable", "farms", 35, "kg", [9, 10, 11], false, "vegetables", "Sep \u2014 Nov", "Ash gourd with dense white flesh, slow-cooked into petha or a cooling sabzi."],
        ["tamatar", "Tamatar", "Tomato", "Solanum lycopersicum", "Vegetable", "farms", 50, "kg", [1, 2, 3], false, "vegetables", "Jan \u2014 Mar", "Sun-ripened tomatoes with enough acidity to carry a winter rasam."],
        ["baingan", "Baingan", "Brinjal", "Solanum melongena", "Vegetable", "farms", 45, "kg", [12, 1, 2, 3], false, "vegetables", "Dec \u2014 Mar", "Small brinjals with few seeds, built for smoky bharta."],
        ["gajar", "Gajar", "Carrot", "Daucus carota", "Vegetable", "farms", 40, "kg", [12, 1, 2], false, "vegetables", "Dec \u2014 Feb", "Sweet winter carrots, good raw, roasted or in gajar halwa."],
        ["matar", "Matar", "Garden peas", "Pisum sativum", "Vegetable", "farms", 100, "kg", [1, 2, 3], false, "vegetables", "Jan \u2014 Mar", "Sweet garden peas picked at dawn, best within a day."],
        ["tarbooz", "Tarbooz", "Watermelon", "Citrullus lanatus", "Fruit", "farms", 25, "kg", [4, 5, 6], false, "melons", "Apr \u2014 Jun", "Dry-season watermelon, irrigated sparingly and picked at full sugar."],
        ["kharbooja", "Kharbooja", "Muskmelon", "Cucumis melo", "Fruit", "farms", 40, "kg", [4, 5, 6], false, "melons", "Apr \u2014 Jun", "Perfumed muskmelon for slow breakfasts and cold soups."],
        ["kheera", "Kheera", "Cucumber", "Cucumis sativus", "Vegetable", "farms", 40, "kg", [3, 4, 5, 6], false, "vegetables", "Mar \u2014 Jun", "Crisp cucumbers from the sand-mulched beds."],
        ["til", "Til", "Sesame", "Sesamum indicum", "Seed", "farms", 220, "kg", [9, 10], false, "grains", "Sep \u2014 Oct", "Sesame seeds for toasted chutneys, til laddoo and cold-pressed oil."],
        ["amla", "Amla", "Indian gooseberry", "Phyllanthus emblica", "Fruit", "orchard", 70, "kg", [11, 12, 1], false, "orchard", "Nov \u2014 Jan", "Tart gooseberry for murabba, juice and the winter pantry."],
        ["ber", "Ber", "Indian jujube", "Ziziphus mauritiana", "Fruit", "orchard", 80, "kg", [12, 1, 2, 3], false, "orchard", "Dec \u2014 Mar", "Small jujubes with an apple-like crunch and a wild edge."],
        ["amrud", "Amrud", "Guava", "Psidium guajava", "Fruit", "orchard", 70, "kg", [11, 12, 1, 2], false, "orchard", "Nov \u2014 Feb", "Fragrant guava from the groves, at its best when the nights turn cool."],
        ["anar", "Anar", "Pomegranate", "Punica granatum", "Fruit", "orchard", 160, "kg", [8, 9, 10, 11], false, "orchard", "Aug \u2014 Nov", "Deep-red pomegranate arils with a bright, mineral finish."],
        ["nimbu", "Nimbu", "Lime", "Citrus limon", "Fruit", "orchard", 60, "kg", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], true, "orchard", "Year-round", "Thin-skinned limes for endless nimbu pani and preserved pickle."],
        ["aam", "Aam", "Mango", "Mangifera indica", "Fruit", "orchard", 140, "kg", [5, 6], false, "orchard", "May \u2014 Jun", "Summer mangoes from the orchard edge, ripened without a cold chain."],
        ["dhaniya", "Dhaniya", "Coriander", "Coriandrum sativum", "Herb", "kitchen", 25, "bunch", [11, 12, 1, 2, 3], false, "herbs", "Nov \u2014 Mar", "Fragrant coriander, cut fresh each morning for the Culinary Lab."],
        ["pudina", "Pudina", "Mint", "Mentha spicata", "Herb", "kitchen", 25, "bunch", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], true, "herbs", "Year-round", "Cool mint for chutneys, teas and the farm's cold buttermilk."],
        ["moringa", "Moringa", "Drumstick greens", "Moringa oleifera", "Herb", "kitchen", 40, "bunch", [4, 5, 6, 7, 8, 9], false, "herbs", "Apr \u2014 Sep", "Tender drumstick greens with a clean, mineral taste."],
        ["curry_patta", "Curry Patta", "Curry leaf", "Murraya koenigii", "Herb", "kitchen", 20, "bunch", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], true, "herbs", "Year-round", "Curry leaves for tempering \u2014 best used the day they are picked."],
        ["microgreens", "Microgreens", "Kitchen trays", "", "Herb", "kitchen", 120, "box", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], true, "herbs", "Year-round", "A rotating tray of pea, radish and mustard shoots for the kitchen."],
        ["doodh", "Doodh", "Fresh milk", "", "Dairy", "dairy", 80, "litre", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], true, "dairy", "Year-round", "Milk from the native herd, collected the same morning."],
        ["ghee", "Ghee", "Cultured ghee", "", "Dairy", "dairy", 650, "jar", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], true, "dairy", "Year-round", "Slow-cultured, hand-churned ghee from the farm dairy."],
        ["ande", "Ande", "Country eggs", "", "Poultry", "dairy", 180, "dozen", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], true, "dairy", "Year-round", "Free-ranging country eggs with deep amber yolks."]
    ];

    var walletStock = {
        bajra: 120, jowar: 90, moth: 48, mung: 60, bhindi: 35, lauki: 55,
        petha: 40, til: 25, anar: 65, nimbu: 80, moringa: 22, doodh: 60
    };
    var walletOffers = {
        bajra: "OFF-11", jowar: "OFF-12", moth: "OFF-13", mung: "OFF-14",
        bhindi: "OFF-15", lauki: "OFF-16", petha: "OFF-17", til: "OFF-18",
        anar: "OFF-19", nimbu: "OFF-20", moringa: "OFF-21", doodh: "OFF-22"
    };

    var now = Date.now();
    var currentMonth = new Date(now).getMonth() + 1;

    function zoneById(id) {
        for (var i = 0; i < zones.length; ++i) if (zones[i].id === id) return zones[i];
        return zones[0];
    }

    function hash32(text) {
        var h = 0x811c9dc5;
        var value = String(text);
        for (var i = 0; i < value.length; ++i) {
            h ^= value.charCodeAt(i);
            h = Math.imul(h, 0x01000193) >>> 0;
        }
        return h >>> 0;
    }

    function seasonNames(months, yearRound) {
        if (yearRound) return ["Year-round"];
        var names = [];
        months.forEach(function (month) {
            var name = month >= 7 && month <= 10 ? "Kharif" : ((month >= 11 || month <= 3) ? "Rabi" : "Zaid");
            if (names.indexOf(name) === -1) names.push(name);
        });
        return names;
    }

    function plotFor(produce, zone) {
        var h = hash32(produce.id);
        var angle = ((h % 360) / 180) * Math.PI;
        var radius = 0.0026 + ((h >>> 9) % 140) / 100000;
        return {
            latitude: Number(zone.latitude) + Math.sin(angle) * radius * 0.82,
            longitude: Number(zone.longitude) + Math.cos(angle) * radius
        };
    }

    function growerFor(produce) {
        var pool = growerPools[produce.zone] || growerPools.farms;
        var id = pool[hash32(produce.id) % pool.length];
        for (var i = 0; i < growers.length; ++i) if (growers[i].id === id) return growers[i];
        return growers[0];
    }

    function inSeason(produce) {
        return produce.yearRound || produce.months.indexOf(currentMonth) !== -1;
    }

    var produce = raw.map(function (row) {
        var zone = zoneById(row[5]);
        var item = {
            id: row[0], name: row[1], local: row[2], botanical: row[3],
            category: row[4], zone: row[5], zoneName: zone.name, zoneColor: zone.color,
            price: row[6], unit: row[7], months: row[8], yearRound: row[9],
            photo: "../assets/produce/" + row[10] + ".jpg",
            harvestLabel: row[11], blurb: row[12],
            seasons: seasonNames(row[8], row[9]),
            plot: plotFor({ id: row[0] }, zone)
        };
        item.grower = growerFor(item);
        item.growerName = item.grower.name;
        item.walletOfferId = walletOffers[item.id] || "";
        item.inSeason = inSeason(item);
        var seedStock = walletStock[item.id];
        if (seedStock === undefined) seedStock = item.inSeason ? 6 + hash32(item.id) % 54 : 0;
        item.stock = seedStock;
        item.updatedAt = now - (8 + hash32("fresh|" + item.id) % 220) * 60000;
        return item;
    });

    function at(offset, hour) {
        var date = new Date();
        date.setDate(date.getDate() + offset);
        date.setHours(hour === undefined ? 8 : hour, 0, 0, 0);
        return date.getTime();
    }

    var seededActivities = [
        {
            id: "FLD-001", role: "dhun", type: "sowing", title: "Walk the rabi seedbed with the steward",
            produceId: "sarson", zone: "farms", date: at(0, 7), status: "planned",
            notes: "Check the 4.5 ha block before the drill closes the sowing window.",
            visibility: "room", source: "programme", media: [], plot: null
        },
        {
            id: "FLD-002", role: "dhun", type: "soil", title: "Seed lot check \u00B7 RH-725",
            produceId: "sarson", zone: "farms", date: at(1, 9), status: "planned",
            notes: "Germination sheet and a sample from the September lot.",
            visibility: "room", source: "programme", media: [], plot: null
        },
        {
            id: "FLD-003", role: "dhun", type: "scouting", title: "Check the bajra drying yard",
            produceId: "bajra", zone: "farms", date: at(2, 12), status: "planned",
            notes: "Moisture reading before the lot is bagged for the market.",
            visibility: "room", source: "programme", media: [], plot: null
        },
        {
            id: "FLD-004", role: "dhun", type: "delivery", title: "Amla drying room handover",
            produceId: "amla", zone: "orchard", date: at(3, 11), status: "planned",
            notes: "Hand the 600 kg batch to the kitchen after grading.",
            visibility: "room", source: "programme", media: [], plot: null
        },
        {
            id: "FLD-005", role: "dhun", type: "review", title: "Weekly programme stand-up",
            produceId: "", zone: "kitchen", date: at(-1, 16), status: "done",
            notes: "Quorum queue, drying room and the nursery mulch window.",
            visibility: "room", source: "programme", media: [], plot: null
        },
        {
            id: "FLD-006", role: "steward", type: "sowing", title: "Sow sarson block \u00B7 4.5 ha",
            produceId: "sarson", zone: "farms", date: at(0, 6), status: "planned",
            notes: "Drill calibrated for the RH-725 lot. Twelve geotagged points required.",
            visibility: "room", source: "challenge", media: [], plot: null
        },
        {
            id: "FLD-007", role: "steward", type: "irrigation", title: "Irrigate kitchen nursery beds",
            produceId: "microgreens", zone: "kitchen", date: at(1, 6), status: "planned",
            notes: "Hold the water buffer; no borewell pumping during covenant hours.",
            visibility: "room", source: "programme", media: [], plot: null
        },
        {
            id: "FLD-008", role: "steward", type: "harvest", title: "Selective amla harvest \u00B7 40 trees",
            produceId: "amla", zone: "orchard", date: at(2, 7), status: "planned",
            notes: "Leave the north-edge fruit and retain 20% on every third tree.",
            visibility: "room", source: "challenge", media: [], plot: null
        },
        {
            id: "FLD-009", role: "steward", type: "compost", title: "Turn compost windrows",
            produceId: "", zone: "farms", date: at(-2, 15), status: "done",
            notes: "Second turn complete. Temperature log filed with the soil panel.",
            visibility: "room", source: "programme", media: [], plot: null
        },
        {
            id: "FLD-010", role: "steward", type: "mulch", title: "Mulch the hedge line before the dry spell",
            produceId: "moringa", zone: "kitchen", date: at(5, 8), status: "planned",
            notes: "Keep the 2 m no-till margin. Two water points stay clear.",
            visibility: "room", source: "programme", media: [], plot: null
        },
        {
            id: "FLD-011", role: "funder", type: "review", title: "Covenant review \u00B7 orchard edge",
            produceId: "amla", zone: "orchard", date: at(4, 10), status: "planned",
            notes: "Review retained-fruit evidence before the next milestone release.",
            visibility: "room", source: "programme", media: [], plot: null
        },
        {
            id: "FLD-012", role: "funder", type: "scouting", title: "Quarterly site walk",
            produceId: "", zone: "farms", date: at(-3, 9), status: "done",
            notes: "Bunds, pasture gap and the pump house. No covenant exceptions.",
            visibility: "room", source: "programme", media: [], plot: null
        }
    ];

    seededActivities.forEach(function (activity) {
        var produceItem = null;
        for (var i = 0; i < produce.length; ++i) if (produce[i].id === activity.produceId) produceItem = produce[i];
        var zone = zoneById(activity.zone);
        activity.plot = produceItem ? produceItem.plot : {
            latitude: zone.latitude + 0.0004,
            longitude: zone.longitude + 0.0004
        };
    });

    var seedUpdates = [
        {
            id: "UPD-001",
            role: "steward",
            kind: "note",
            title: "Amla M1 evidence filed",
            text: "Picked 38 of 40 marker trees. The north-edge fruit stays for the next pass; 20% retained on every third tree.",
            produceId: "amla",
            zone: "orchard",
            at: at(-1, 15),
            shared: true,
            mediaId: ""
        },
        {
            id: "UPD-002",
            role: "dhun",
            kind: "note",
            title: "Sowing window is tight",
            text: "The sarson drill is calibrated. If the block is not sown before Thursday, we lose the December establishment window.",
            produceId: "sarson",
            zone: "farms",
            at: at(0, 7),
            shared: true,
            mediaId: ""
        }
    ];

    root.DHUN_DATA = {
        schema: 1,
        seededAt: now,
        site: site,
        zones: zones,
        growers: growers,
        growerPools: growerPools,
        activityTypes: activityTypes,
        produce: produce,
        seededActivities: seededActivities,
        seedUpdates: seedUpdates,
        currentMonth: currentMonth
    };
}(typeof window !== "undefined" ? window : globalThis));
