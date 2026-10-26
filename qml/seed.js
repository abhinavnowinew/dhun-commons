.pragma library

var SCHEMA = 4;

function hash32(text) {
    var h = 0x811c9dc5;
    var value = String(text);
    for (var i = 0; i < value.length; ++i) {
        h ^= value.charCodeAt(i);
        h = Math.imul(h, 0x01000193) >>> 0;
    }
    return ("00000000" + h.toString(16)).slice(-8);
}

function longHash(seed) {
    var out = "";
    var round = 0;
    while (out.length < 40) {
        out += hash32(String(seed) + ":" + round);
        round += 1;
    }
    return out.slice(0, 40);
}

function makeDigest(id, kind, amount, createdAt, expiresAt) {
    return "0x" + longHash([id, kind, amount, createdAt, expiresAt].join("|"));
}

function makeTx(seed) {
    return "0x" + longHash(seed) + longHash(seed + "|tail").slice(0, 8);
}

function makeSig(role, id) {
    return "demo-" + longHash(role + "|" + id + "|approval").slice(0, 32);
}

var DAY = 86400000;
var HOUR = 3600000;

function dayAt(seedNow, offset, hour) {
    var date = new Date(seedNow);
    date.setDate(date.getDate() + Number(offset || 0));
    date.setHours(hour === undefined ? 8 : hour, 0, 0, 0);
    return date.getTime();
}

function build(now) {
    var seedNow = Number(now) || Date.now();

    var roles = {
        funder: {
            id: "funder",
            label: "Funder",
            short: "Funder",
            org: "Dhun Capital Circle",
            signer: "A. Rao · capital steward",
            address: "dhun1qfunder8m4c2v7n9s",
            keyFingerprint: "8F2A · 91C4 · 7D0E",
            color: "#E0B25C",
            soft: "#F4E4C5",
            text: "#4C3510",
            mandate: "Capital, external settlement and market issuance",
            allowance: 0,
            reputation: 96,
            completed: 14,
            onTime: 98,
            team: "Funder desk"
        },
        dhun: {
            id: "dhun",
            label: "Dhun",
            short: "Dhun",
            org: "Dhun Field Unit",
            signer: "M. Singh · site coordinator",
            address: "dhun1qdhun6p3a9k2e4t",
            keyFingerprint: "3C7B · A120 · 44E9",
            color: "#B9D567",
            soft: "#EDF1E4",
            text: "#20320D",
            mandate: "Site mandate, project coordination and task allocation",
            allowance: 500,
            reputation: 92,
            completed: 23,
            onTime: 91,
            team: "Dhun Field Unit"
        },
        steward: {
            id: "steward",
            label: "Steward",
            short: "Steward",
            org: "Khejri Mandal",
            signer: "K. Devi · steward collective",
            address: "dhun1qsteward2w8r5h7c",
            keyFingerprint: "D091 · 5A3F · 2B88",
            color: "#C76B47",
            soft: "#F3DED4",
            text: "#4D2514",
            mandate: "Field execution, resource requests and evidence",
            allowance: 500,
            reputation: 89,
            completed: 31,
            onTime: 94,
            team: "Khejri Mandal"
        }
    };

    var wallets = {
        funder: 8000,
        dhun: 4000,
        steward: 3000,
        vault: 50000,
        projectEscrow: 28000,
        challengeEscrow: 10000,
        conservation: 7000,
        external: 40000,
        suppliers: 0
    };

    var proposals = [
        {
            id: "PROP-105",
            kind: "mint",
            title: "Issue Tranche C",
            summary: "Rabi working capital: soil programme, seed bank fit-out and two new field challenges.",
            amount: 20000,
            from: "funder",
            to: "vault",
            target: "dhun_multisig::mint",
            status: "pending",
            createdBy: "funder",
            createdAt: seedNow - 6 * HOUR,
            expiresAt: seedNow + 66 * HOUR,
            timelock: 0,
            quorum: 2,
            approvals: [{ role: "funder", at: seedNow - 6 * HOUR, sig: makeSig("funder", "PROP-105") }],
            rejections: [],
            meta: {
                tranche: "Tranche C · Rabi 2026",
                collateral: 200000,
                purpose: "Fund rabi soil, seed bank and two new challenges"
            },
            digest: makeDigest("PROP-105", "mint", 20000, seedNow - 6 * HOUR, seedNow + 66 * HOUR)
        },
        {
            id: "PROP-106",
            kind: "sale",
            title: "Sell 6,000 DHN externally",
            summary: "Place a tranche with the Jaipur Food Co-op at a ₹10.50 floor, proceeds to the settlement account.",
            amount: 6000,
            from: "vault",
            to: "external",
            target: "dhun_multisig::external_sale",
            status: "pending",
            createdBy: "funder",
            createdAt: seedNow - 2 * HOUR,
            expiresAt: seedNow + 46 * HOUR,
            timelock: 0,
            quorum: 2,
            approvals: [{ role: "funder", at: seedNow - 2 * HOUR, sig: makeSig("funder", "PROP-106") }],
            rejections: [],
            meta: {
                buyer: "Jaipur Food Co-op (external)",
                price: 10.5,
                proceeds: 63000
            },
            digest: makeDigest("PROP-106", "sale", 6000, seedNow - 2 * HOUR, seedNow + 46 * HOUR)
        },
        {
            id: "PROP-107",
            kind: "award",
            title: "Award seed bank to Khejri Mandal",
            summary: "Select the local stone-plinth bid: 5,600 DHN, 21 days, strongest conservation detail.",
            amount: 5600,
            from: "projectEscrow",
            to: "steward",
            target: "dhun_multisig::award",
            status: "pending",
            createdBy: "funder",
            createdAt: seedNow - 1 * HOUR,
            expiresAt: seedNow + 47 * HOUR,
            timelock: 0,
            quorum: 2,
            approvals: [{ role: "funder", at: seedNow - 1 * HOUR, sig: makeSig("funder", "PROP-107") }],
            rejections: [],
            meta: { projectId: "PRJ-03", bidId: "BID-201" },
            digest: makeDigest("PROP-107", "award", 5600, seedNow - 1 * HOUR, seedNow + 47 * HOUR)
        },
        {
            id: "PROP-108",
            kind: "release",
            title: "Release Amla milestone M1",
            summary: "Selective harvest evidence accepted. 8% of the release goes to the orchard-retention covenant.",
            amount: 3200,
            from: "projectEscrow",
            to: "steward",
            target: "dhun_multisig::release",
            status: "pending",
            createdBy: "dhun",
            createdAt: seedNow - 5 * HOUR,
            readyAt: seedNow - 4 * HOUR,
            expiresAt: seedNow + 43 * HOUR,
            timelock: 0,
            quorum: 2,
            approvals: [
                { role: "dhun", at: seedNow - 5 * HOUR, sig: makeSig("dhun", "PROP-108") },
                { role: "funder", at: seedNow - 4 * HOUR, sig: makeSig("funder", "PROP-108") }
            ],
            rejections: [],
            meta: { projectId: "PRJ-02", milestoneId: "M1" },
            conservationPct: 8,
            digest: makeDigest("PROP-108", "release", 3200, seedNow - 5 * HOUR, seedNow + 43 * HOUR)
        },
        {
            id: "PROP-109",
            kind: "purchase",
            title: "Buy screened vermicompost",
            summary: "Two tonnes for the rabi beds. Above the 500 DHN single-signer allowance, so it needs a co-sign.",
            amount: 640,
            from: "steward",
            to: "suppliers",
            target: "dhun_commons.market::purchase",
            status: "pending",
            createdBy: "steward",
            createdAt: seedNow - 30 * 60000,
            expiresAt: seedNow + 71.5 * HOUR,
            timelock: 0,
            quorum: 2,
            approvals: [{ role: "steward", at: seedNow - 30 * 60000, sig: makeSig("steward", "PROP-109") }],
            rejections: [],
            meta: { offerId: "OFF-02", qty: 1 },
            digest: makeDigest("PROP-109", "purchase", 640, seedNow - 30 * 60000, seedNow + 71.5 * HOUR)
        }
    ];

    var ledger = [
        {
            id: "LED-001",
            kind: "issue",
            title: "Treasury opened",
            detail: "Tranche A · 150,000 DHN fully backed at a ₹10 floor",
            amount: 150000,
            from: "issuance",
            to: "vault",
            at: seedNow - 30 * DAY,
            txid: makeTx("opening-150"),
            proposalId: ""
        },
        {
            id: "LED-002",
            kind: "allocate",
            title: "Project escrow allocated",
            detail: "Rabi soil, amla harvest and seed bank programmes",
            amount: 28000,
            from: "vault",
            to: "projectEscrow",
            at: seedNow - 21 * DAY,
            txid: makeTx("project-escrow"),
            proposalId: ""
        },
        {
            id: "LED-003",
            kind: "allocate",
            title: "Challenge pool allocated",
            detail: "Four time-sensitive cultivation windows",
            amount: 10000,
            from: "vault",
            to: "challengeEscrow",
            at: seedNow - 18 * DAY,
            txid: makeTx("challenge-pool"),
            proposalId: ""
        },
        {
            id: "LED-004",
            kind: "allocate",
            title: "Conservation covenant reserve",
            detail: "Opening reserve for water, habitat and orchard retention",
            amount: 7000,
            from: "vault",
            to: "conservation",
            at: seedNow - 16 * DAY,
            txid: makeTx("conservation-open"),
            proposalId: ""
        },
        {
            id: "LED-005",
            kind: "sale",
            title: "External placement",
            detail: "40,000 DHN placed with external holders · ₹4,20,000 raised",
            amount: 40000,
            from: "vault",
            to: "external",
            at: seedNow - 12 * DAY,
            txid: makeTx("external-placement"),
            proposalId: ""
        },
        {
            id: "LED-006",
            kind: "distribution",
            title: "Operating float · Funder",
            detail: "Market desk float",
            amount: 8000,
            from: "vault",
            to: "funder",
            at: seedNow - 10 * DAY,
            txid: makeTx("float-funder"),
            proposalId: ""
        },
        {
            id: "LED-007",
            kind: "distribution",
            title: "Operating float · Dhun",
            detail: "Field coordination float",
            amount: 4000,
            from: "vault",
            to: "dhun",
            at: seedNow - 10 * DAY,
            txid: makeTx("float-dhun"),
            proposalId: ""
        },
        {
            id: "LED-008",
            kind: "distribution",
            title: "Operating float · Steward",
            detail: "Khejri Mandal field float",
            amount: 3000,
            from: "vault",
            to: "steward",
            at: seedNow - 10 * DAY,
            txid: makeTx("float-steward"),
            proposalId: ""
        }
    ];

    var offers = [
        {
            id: "OFF-01",
            supplier: "Shekhawati Seed Co-op",
            title: "Certified sarson seed · RH-725",
            description: "Rabi mustard seed from the 2026 lot. Germination 94%, tested September 2026.",
            category: "Seed & inputs",
            price: 380,
            unit: "20 kg lot",
            stock: 6,
            zone: "farms",
            season: "Rabi",
            verified: true,
            rating: 4.8,
            lead: "2 days"
        },
        {
            id: "OFF-02",
            supplier: "Gulabpura Vermi Collective",
            title: "Screened vermicompost",
            description: "Two-tonne load, screened to 6 mm. Suitable for nursery beds and the kitchen garden.",
            category: "Soil & compost",
            price: 640,
            unit: "2 t load",
            stock: 4,
            zone: "farms",
            season: "Year-round",
            verified: true,
            rating: 4.6,
            lead: "3 days"
        },
        {
            id: "OFF-03",
            supplier: "Aravalli Irrigation",
            title: "Drip tape kit · 1 acre",
            description: "16 mm tape, filter and fittings for one acre of closely spaced vegetables.",
            category: "Water & tools",
            price: 1250,
            unit: "1 acre kit",
            stock: 3,
            zone: "farms",
            season: "Year-round",
            verified: true,
            rating: 4.4,
            lead: "5 days"
        },
        {
            id: "OFF-04",
            supplier: "Jaipur Fresh Hub",
            title: "Cold room · 3 days",
            description: "Palletised cold storage at 4 °C for the amla and leafy-green handover.",
            category: "Processing & storage",
            price: 480,
            unit: "3-day block",
            stock: 2,
            zone: "dairy",
            season: "Year-round",
            verified: true,
            rating: 4.2,
            lead: "book 48h ahead"
        },
        {
            id: "OFF-05",
            supplier: "Surya Food Lab",
            title: "Solar dryer rental · 10 days",
            description: "Two-tray solar dryer with temperature log, for the amla drying milestone.",
            category: "Processing & storage",
            price: 900,
            unit: "10-day block",
            stock: 2,
            zone: "kitchen",
            season: "Rabi",
            verified: true,
            rating: 4.7,
            lead: "4 days"
        },
        {
            id: "OFF-06",
            supplier: "Khejri Labour Pool",
            title: "Seasonal field crew · 6 person-days",
            description: "Six experienced person-days for bed preparation, sowing or selective harvest.",
            category: "Labour",
            price: 720,
            unit: "6 person-days",
            stock: 5,
            zone: "farms",
            season: "Rabi",
            verified: true,
            rating: 4.5,
            lead: "72 hours"
        },
        {
            id: "OFF-07",
            supplier: "Bioreserve Nursery",
            title: "Native hedge saplings · 300",
            description: "Khejri, ker and lasora saplings for the pollinator strip. Nursery stock, local provenance.",
            category: "Conservation",
            price: 1100,
            unit: "300 saplings",
            stock: 3,
            zone: "orchard",
            season: "Jul — Sep",
            verified: true,
            rating: 4.9,
            lead: "10 days",
            covenant: true
        },
        {
            id: "OFF-08",
            supplier: "SoilLab Jaipur",
            title: "Soil microbiology panel",
            description: "Organic carbon, respiration and microbial biomass baseline for one management block.",
            category: "Soil & compost",
            price: 350,
            unit: "1 panel",
            stock: 8,
            zone: "farms",
            season: "Year-round",
            verified: true,
            rating: 4.8,
            lead: "1 day"
        },
        {
            id: "OFF-11",
            kind: "produce",
            ingredientId: "bajra",
            growerId: "dhun-field",
            supplier: "Dhun Field Unit",
            title: "Bajra · pearl millet",
            description: "Rain-fed pearl millet, cleaned and sun-dried at the farm. This week's lot from the kharif plots.",
            category: "Produce",
            price: 55,
            unit: "kg",
            stock: 120,
            zone: "farms",
            season: "Kharif",
            verified: true,
            rating: 4.8,
            lead: "ready today",
            harvestedAt: dayAt(seedNow, -1, 7),
            updatedAt: seedNow - 18 * 60000
        },
        {
            id: "OFF-12",
            kind: "produce",
            ingredientId: "jowar",
            growerId: "dhun-field",
            supplier: "Dhun Field Unit",
            title: "Jowar · sorghum",
            description: "Soft white sorghum from the rain-fed block. Milled to order for bhakri and porridge.",
            category: "Produce",
            price: 65,
            unit: "kg",
            stock: 90,
            zone: "farms",
            season: "Kharif",
            verified: true,
            rating: 4.7,
            lead: "ready today",
            harvestedAt: dayAt(seedNow, -2, 8),
            updatedAt: seedNow - 42 * 60000
        },
        {
            id: "OFF-13",
            kind: "produce",
            ingredientId: "moth",
            growerId: "shekhawati-seed",
            supplier: "Shekhawati Seed Co-op",
            title: "Moth · moth bean",
            description: "Small desert beans from the co-op's cleaned kharif lot. Firm bite, quick cooking.",
            category: "Produce",
            price: 120,
            unit: "kg",
            stock: 48,
            zone: "farms",
            season: "Kharif",
            verified: true,
            rating: 4.9,
            lead: "ready today",
            harvestedAt: dayAt(seedNow, -4, 9),
            updatedAt: seedNow - 2 * HOUR
        },
        {
            id: "OFF-14",
            kind: "produce",
            ingredientId: "mung",
            growerId: "shekhawati-seed",
            supplier: "Shekhawati Seed Co-op",
            title: "Mung · green gram",
            description: "Bright green gram, graded and sealed. A small lot from the second picking.",
            category: "Produce",
            price: 140,
            unit: "kg",
            stock: 60,
            zone: "farms",
            season: "Kharif",
            verified: true,
            rating: 4.8,
            lead: "ready today",
            harvestedAt: dayAt(seedNow, -5, 8),
            updatedAt: seedNow - 3 * HOUR
        },
        {
            id: "OFF-15",
            kind: "produce",
            ingredientId: "bhindi",
            growerId: "dhun-field",
            supplier: "Dhun Field Unit",
            title: "Bhindi · okra",
            description: "Small, glossy pods picked this morning. Best within two days.",
            category: "Produce",
            price: 70,
            unit: "kg",
            stock: 35,
            zone: "farms",
            season: "Kharif",
            verified: true,
            rating: 4.8,
            lead: "picked today",
            harvestedAt: dayAt(seedNow, 0, 6),
            updatedAt: seedNow - 12 * 60000
        },
        {
            id: "OFF-16",
            kind: "produce",
            ingredientId: "lauki",
            growerId: "dhun-field",
            supplier: "Dhun Field Unit",
            title: "Lauki · bottle gourd",
            description: "Tender bottle gourds from the sand-mulched beds. Cut to order.",
            category: "Produce",
            price: 35,
            unit: "kg",
            stock: 55,
            zone: "farms",
            season: "Kharif",
            verified: true,
            rating: 4.6,
            lead: "picked today",
            harvestedAt: dayAt(seedNow, 0, 6),
            updatedAt: seedNow - 28 * 60000
        },
        {
            id: "OFF-17",
            kind: "produce",
            ingredientId: "petha",
            growerId: "dhun-field",
            supplier: "Dhun Field Unit",
            title: "Petha · ash gourd",
            description: "Dense white-fleshed ash gourd, field-cured for storage. Half or full fruit.",
            category: "Produce",
            price: 35,
            unit: "kg",
            stock: 40,
            zone: "farms",
            season: "Kharif",
            verified: true,
            rating: 4.7,
            lead: "ready today",
            harvestedAt: dayAt(seedNow, -2, 7),
            updatedAt: seedNow - HOUR
        },
        {
            id: "OFF-18",
            kind: "produce",
            ingredientId: "til",
            growerId: "shekhawati-seed",
            supplier: "Shekhawati Seed Co-op",
            title: "Til · sesame",
            description: "Toasted-white sesame seed, cleaned for chutney and cold-pressed oil.",
            category: "Produce",
            price: 220,
            unit: "kg",
            stock: 25,
            zone: "farms",
            season: "Kharif",
            verified: true,
            rating: 4.9,
            lead: "ready today",
            harvestedAt: dayAt(seedNow, -7, 9),
            updatedAt: seedNow - 5 * HOUR
        },
        {
            id: "OFF-19",
            kind: "produce",
            ingredientId: "anar",
            growerId: "khejri",
            supplier: "Khejri Mandal",
            title: "Anar · pomegranate",
            description: "Deep-red arils from the orchard edge. Graded by hand; 20% of the crop is retained for the nesting covenant.",
            category: "Produce",
            price: 160,
            unit: "kg",
            stock: 65,
            zone: "orchard",
            season: "Kharif",
            verified: true,
            rating: 4.9,
            lead: "ready today",
            harvestedAt: dayAt(seedNow, -1, 7),
            updatedAt: seedNow - 22 * 60000,
            covenant: true
        },
        {
            id: "OFF-20",
            kind: "produce",
            ingredientId: "nimbu",
            growerId: "khejri",
            supplier: "Khejri Mandal",
            title: "Nimbu · lime",
            description: "Thin-skinned limes from the grove. Picked to order through the season.",
            category: "Produce",
            price: 60,
            unit: "kg",
            stock: 80,
            zone: "orchard",
            season: "Year-round",
            verified: true,
            rating: 4.7,
            lead: "ready today",
            harvestedAt: dayAt(seedNow, 0, 7),
            updatedAt: seedNow - 35 * 60000
        },
        {
            id: "OFF-21",
            kind: "produce",
            ingredientId: "moringa",
            growerId: "bhawani",
            supplier: "Bhawani Women's Collective",
            title: "Moringa · drumstick greens",
            description: "Tender moringa greens cut at sunrise by the kitchen garden collective.",
            category: "Produce",
            price: 40,
            unit: "bunch",
            stock: 22,
            zone: "kitchen",
            season: "Kharif",
            verified: true,
            rating: 4.8,
            lead: "picked today",
            harvestedAt: dayAt(seedNow, 0, 6),
            updatedAt: seedNow - 9 * 60000
        },
        {
            id: "OFF-22",
            kind: "produce",
            ingredientId: "doodh",
            growerId: "gulabpura-dairy",
            supplier: "Gulabpura Dairy",
            title: "Doodh · fresh milk",
            description: "Morning milk from the native herd, chilled in the dairy within the hour.",
            category: "Produce",
            price: 80,
            unit: "litre",
            stock: 60,
            zone: "dairy",
            season: "Year-round",
            verified: true,
            rating: 4.9,
            lead: "collected today",
            harvestedAt: dayAt(seedNow, 0, 5),
            updatedAt: seedNow - 6 * 60000
        }
    ];

    var projects = [
        {
            id: "PRJ-01",
            code: "SOIL / RABI",
            title: "Rabi soil & water programme",
            summary: "Contour bunds, screened compost and a legume cover crop across 18 hectares of the rabi blocks. The programme keeps the pasture gap and leaves the orchard nesting strip undisturbed.",
            zone: "farms",
            zones: ["farms", "kitchen"],
            season: "Rabi",
            window: "Nov — Feb 2026–27",
            budget: 14000,
            conservationPct: 10,
            status: "active",
            funded: true,
            awardedTo: "dhun",
            awardedName: "Dhun Field Unit",
            createdAt: seedNow - 20 * DAY,
            room: "room-soil",
            milestones: [
                {
                    id: "M1",
                    title: "Contour survey & bund layout",
                    amount: 4000,
                    status: "evidence",
                    evidence: "Stake plan, bund profile sheet and 12 geotagged photos. The pasture gap is marked in yellow.",
                    due: seedNow + 2 * DAY,
                    submittedAt: seedNow - 6 * HOUR
                },
                {
                    id: "M2",
                    title: "Compost incorporation · 18 ha",
                    amount: 6000,
                    status: "active",
                    evidence: "",
                    due: seedNow + 14 * DAY,
                    submittedAt: 0
                },
                {
                    id: "M3",
                    title: "Legume cover established",
                    amount: 4000,
                    status: "planned",
                    evidence: "",
                    due: seedNow + 32 * DAY,
                    submittedAt: 0
                }
            ],
            bids: [
                {
                    id: "BID-101",
                    bidder: "dhun",
                    team: "Dhun Field Unit",
                    amount: 13800,
                    days: 34,
                    plan: "Two field crews, laser survey and a shared compost bay. Weekly photo log and a 0.9 m bund profile.",
                    reputation: 92,
                    score: 88,
                    status: "selected"
                },
                {
                    id: "BID-102",
                    bidder: "steward",
                    team: "Khejri Mandal",
                    amount: 13500,
                    days: 39,
                    plan: "Village labour pool with hand-built bunds. Lower cash cost, slower around the irrigation window.",
                    reputation: 89,
                    score: 84,
                    status: "not selected"
                }
            ]
        },
        {
            id: "PRJ-02",
            code: "AMLA / VALUE",
            title: "Amla harvest & solar drying",
            summary: "A selective harvest across 40 marker trees, followed by solar drying, grading and a traceable handover to the kitchen. The orchard nesting covenant stays in force.",
            zone: "orchard",
            zones: ["orchard"],
            season: "Rabi",
            window: "Nov — Dec 2026",
            budget: 8000,
            conservationPct: 8,
            status: "active",
            funded: true,
            awardedTo: "steward",
            awardedName: "Khejri Mandal",
            createdAt: seedNow - 16 * DAY,
            room: "room-amla",
            milestones: [
                {
                    id: "M1",
                    title: "Selective harvest · 40 marker trees",
                    amount: 3200,
                    status: "evidence",
                    evidence: "Harvest log for 38 trees, moisture readings, 18 photos and 20% fruit retained on every third tree. Two trees left unripe.",
                    due: seedNow + 1 * DAY,
                    submittedAt: seedNow - 2 * HOUR
                },
                {
                    id: "M2",
                    title: "Solar drying & grading · 600 kg",
                    amount: 2800,
                    status: "active",
                    evidence: "",
                    due: seedNow + 12 * DAY,
                    submittedAt: 0
                },
                {
                    id: "M3",
                    title: "Batch traceability & handover",
                    amount: 2000,
                    status: "planned",
                    evidence: "",
                    due: seedNow + 24 * DAY,
                    submittedAt: 0
                }
            ],
            bids: [
                {
                    id: "BID-201",
                    bidder: "steward",
                    team: "Khejri Mandal",
                    amount: 7800,
                    days: 28,
                    plan: "Selective hand harvest with the existing orchard crew. Retain 20% fruit and log every marker tree.",
                    reputation: 89,
                    score: 91,
                    status: "selected"
                },
                {
                    id: "BID-202",
                    bidder: "dhun",
                    team: "Dhun Field Unit",
                    amount: 7600,
                    days: 32,
                    plan: "Mechanised picking bars and a shared drying room. Faster on volume, higher fruit bruising risk.",
                    reputation: 92,
                    score: 79,
                    status: "not selected"
                }
            ]
        },
        {
            id: "PRJ-03",
            code: "SEED / STORE",
            title: "Community seed bank fit-out",
            summary: "Fit out the existing stone room with humidity control, sealed bins and a simple accession ledger for 22 local varieties. Three teams are competing for the award.",
            zone: "farms",
            zones: ["farms"],
            season: "Year-round",
            window: "Nov — Jan 2026–27",
            budget: 6000,
            conservationPct: 5,
            status: "bidding",
            funded: true,
            awardedTo: "",
            awardedName: "",
            createdAt: seedNow - 9 * DAY,
            room: "room-seed",
            milestones: [
                {
                    id: "M1",
                    title: "Humidity room & plinth",
                    amount: 2400,
                    status: "planned",
                    evidence: "",
                    due: seedNow + 18 * DAY,
                    submittedAt: 0
                },
                {
                    id: "M2",
                    title: "Sealed bins & accession ledger",
                    amount: 2100,
                    status: "planned",
                    evidence: "",
                    due: seedNow + 28 * DAY,
                    submittedAt: 0
                },
                {
                    id: "M3",
                    title: "First 22 accessions entered",
                    amount: 1500,
                    status: "planned",
                    evidence: "",
                    due: seedNow + 38 * DAY,
                    submittedAt: 0
                }
            ],
            bids: [
                {
                    id: "BID-201",
                    bidder: "steward",
                    team: "Khejri Mandal",
                    amount: 5600,
                    days: 21,
                    plan: "Reuse the existing stone plinth, local labour, and a sealed-bin fit-out sourced from Jaipur. Keeps 70% of spend in the village.",
                    reputation: 89,
                    score: 91,
                    status: "open"
                },
                {
                    id: "BID-202",
                    bidder: "dhun",
                    team: "Dhun Field Unit",
                    amount: 5900,
                    days: 18,
                    plan: "Prefabricated humidity panel and a two-week install. Highest uptime, but the panel and freight leave the district.",
                    reputation: 92,
                    score: 87,
                    status: "open"
                },
                {
                    id: "BID-203",
                    bidder: "steward",
                    team: "Bhawani Women's Collective",
                    amount: 5400,
                    days: 26,
                    plan: "Lowest price and a women-led crew. Needs a curing week for the lime plaster before the bins land.",
                    reputation: 84,
                    score: 83,
                    status: "open"
                }
            ]
        },
        {
            id: "PRJ-04",
            code: "HABITAT / EDGE",
            title: "Habitat hedge & pollinator strip",
            summary: "A 300-sapling native hedge along the kitchen-garden edge, with a no-till margin and two water points. The first project proposed under the habitat covenant.",
            zone: "kitchen",
            zones: ["kitchen", "orchard"],
            season: "Monsoon 2027",
            window: "Jul — Sep 2027",
            budget: 4000,
            conservationPct: 25,
            status: "draft",
            funded: false,
            awardedTo: "",
            awardedName: "",
            createdAt: seedNow - 2 * DAY,
            room: "room-habitat",
            milestones: [
                {
                    id: "M1",
                    title: "Hedge line & water points",
                    amount: 1600,
                    status: "planned",
                    evidence: "",
                    due: seedNow + 60 * DAY,
                    submittedAt: 0
                },
                {
                    id: "M2",
                    title: "Plant 300 native saplings",
                    amount: 1400,
                    status: "planned",
                    evidence: "",
                    due: seedNow + 80 * DAY,
                    submittedAt: 0
                },
                {
                    id: "M3",
                    title: "Establishment & survival check",
                    amount: 1000,
                    status: "planned",
                    evidence: "",
                    due: seedNow + 120 * DAY,
                    submittedAt: 0
                }
            ],
            bids: []
        }
    ];

    var challenges = [
        {
            id: "CH-01",
            code: "SOW / 72H",
            title: "Sow sarson before the window closes",
            summary: "Direct-sow the 4.5 ha rabi mustard block while the soil moisture is still in the seedbed. Late sowing loses the December establishment window.",
            projectId: "PRJ-01",
            zone: "farms",
            bounty: 2400,
            conservationPct: 5,
            windowEnd: seedNow + 2 * DAY + 7 * HOUR,
            evidenceSpec: "Seed lot photo, drill calibration sheet and 12 geotagged points across the block.",
            status: "open",
            claimedBy: "",
            claimedName: "",
            claimedAt: 0,
            evidence: "",
            createdBy: "dhun",
            room: "room-soil"
        },
        {
            id: "CH-02",
            code: "AMLA / SELECT",
            title: "Amla selective harvest · 40 marker trees",
            summary: "Pick only ripe fruit from the marked trees and retain 20% for the nesting covenant. Two unripe trees stay untouched until the next pass.",
            projectId: "PRJ-02",
            zone: "orchard",
            bounty: 1800,
            conservationPct: 8,
            windowEnd: seedNow + 8 * DAY,
            evidenceSpec: "Marker-tree log, photos of retained fruit and a moisture reading for the drying batch.",
            status: "open",
            claimedBy: "",
            claimedName: "",
            claimedAt: 0,
            evidence: "",
            createdBy: "dhun",
            room: "room-amla"
        },
        {
            id: "CH-03",
            code: "WATER / TRENCH",
            title: "Contour trench above kitchen garden",
            summary: "Cut and check the 120 m contour trench before the next irrigation cycle. The spoil goes into the bund, not the kitchen beds.",
            projectId: "PRJ-01",
            zone: "kitchen",
            bounty: 2200,
            conservationPct: 15,
            windowEnd: seedNow + 4 * DAY,
            evidenceSpec: "Trench profile, 9 geotagged photos, check-dam level and a before/after water-line photo.",
            status: "evidence",
            claimedBy: "steward",
            claimedName: "Khejri Mandal",
            claimedAt: seedNow - 1 * DAY,
            evidence: "120 m cut to a 0.6 m profile, check dam keyed into the bund. Nine photos and a level reading uploaded. Water line held overnight.",
            createdBy: "dhun",
            room: "room-soil"
        },
        {
            id: "CH-04",
            code: "SEED / CLEAN",
            title: "Clean & grade 400 kg bajra seed",
            summary: "Winnow, grade and seal the bajra seed stock for the community bank. Keep the accession labels with each lot.",
            projectId: "PRJ-03",
            zone: "farms",
            bounty: 1600,
            conservationPct: 0,
            windowEnd: seedNow + 36 * HOUR,
            evidenceSpec: "Weight before/after, accession labels and photos of the sealed bins.",
            status: "claimed",
            claimedBy: "dhun",
            claimedName: "Dhun Field Unit",
            claimedAt: seedNow - 5 * HOUR,
            evidence: "",
            createdBy: "steward",
            room: "room-seed"
        }
    ];

    var channels = [
        { id: "room-msig", name: "Multisig · all signers", subtitle: "Funder · Dhun · Steward", kind: "multisig", unread: 2 },
        { id: "room-soil", name: "Rabi soil programme", subtitle: "PRJ-01 · 3 signers + field", kind: "project", unread: 1 },
        { id: "room-amla", name: "Amla harvest", subtitle: "PRJ-02 · Khejri Mandal", kind: "project", unread: 0 },
        { id: "room-seed", name: "Seed bank award", subtitle: "PRJ-03 · 3 competing bids", kind: "project", unread: 1 },
        { id: "room-habitat", name: "Habitat hedge", subtitle: "PRJ-04 · draft", kind: "project", unread: 0 }
    ];

    var messages = {
        "room-msig": [
            {
                id: "MSG-001",
                role: "system",
                kind: "system",
                text: "2-of-3 quorum · three signers bound to this room. The program checks validity at execution; the room is never trusted for it.",
                at: seedNow - 2 * DAY
            },
            {
                id: "MSG-002",
                role: "funder",
                kind: "text",
                text: "Tranche C is queued for the rabi push. The ₹2,00,000 collateral is in the settlement account. I have signed; need one more.",
                at: seedNow - 6 * HOUR + 5 * 60000
            },
            {
                id: "MSG-003",
                role: "dhun",
                kind: "text",
                text: "Amla M1 evidence is up and the release has both signatures. Steward, can you confirm the drying room before we execute?",
                at: seedNow - 3.5 * HOUR
            },
            {
                id: "MSG-004",
                role: "system",
                kind: "system",
                text: "PROP-108 reached quorum · 2 of 3 approvals · ready to execute.",
                at: seedNow - 4 * HOUR
            },
            {
                id: "MSG-005",
                role: "steward",
                kind: "text",
                text: "Compost purchase is 640 DHN, above my 500 allowance. I left it for a co-sign rather than split the order.",
                at: seedNow - 28 * 60000
            }
        ],
        "room-soil": [
            {
                id: "MSG-010",
                role: "dhun",
                kind: "text",
                text: "Bund layout is staked. We held the 0.9 m profile and kept the pasture gap. Evidence is attached to M1.",
                at: seedNow - 7 * HOUR
            },
            {
                id: "MSG-011",
                role: "steward",
                kind: "text",
                text: "Compost lands Thursday. We can incorporate Friday if the release clears.",
                at: seedNow - 5 * HOUR
            },
            {
                id: "MSG-012",
                role: "system",
                kind: "system",
                text: "Milestone M1 evidence submitted · 4,000 DHN awaiting release. Conservation covenant: 10%.",
                at: seedNow - 6 * HOUR
            }
        ],
        "room-amla": [
            {
                id: "MSG-020",
                role: "steward",
                kind: "text",
                text: "Picked 38 of the 40 marker trees. The two at the north edge are still unripe; we left them. 20% retained on every third tree.",
                at: seedNow - 3 * HOUR
            },
            {
                id: "MSG-021",
                role: "dhun",
                kind: "text",
                text: "Good call. Keep the north-edge fruit out of this batch. Solar dryer is booked for the day after release.",
                at: seedNow - 2.5 * HOUR
            },
            {
                id: "MSG-022",
                role: "system",
                kind: "system",
                text: "M1 evidence filed · release PROP-108 has quorum and is ready to execute.",
                at: seedNow - 2 * HOUR
            }
        ],
        "room-seed": [
            {
                id: "MSG-030",
                role: "funder",
                kind: "text",
                text: "Three bids on the seed bank. Khejri is 300 DHN under our field unit and keeps most of the spend in the village.",
                at: seedNow - 1.5 * HOUR
            },
            {
                id: "MSG-031",
                role: "dhun",
                kind: "text",
                text: "Our prefab quote is 300 higher but two weeks faster. I am happy to lose on the conservation score; that is the point of competing.",
                at: seedNow - 1.2 * HOUR
            },
            {
                id: "MSG-032",
                role: "steward",
                kind: "text",
                text: "The stone plinth is already there. We can start Monday and use the existing curing shed.",
                at: seedNow - 50 * 60000
            },
            {
                id: "MSG-033",
                role: "system",
                kind: "system",
                text: "Award proposal PROP-107 · Khejri Mandal · 5,600 DHN · collecting the second signature.",
                at: seedNow - 1 * HOUR
            }
        ],
        "room-habitat": [
            {
                id: "MSG-040",
                role: "dhun",
                kind: "text",
                text: "The hedge line is marked but the project is still a draft. Fund it before the monsoon nursery order closes.",
                at: seedNow - 2 * DAY
            },
            {
                id: "MSG-041",
                role: "system",
                kind: "system",
                text: "Draft project · not funded · no tokens committed. 25% conservation covenant proposed.",
                at: seedNow - 2 * DAY
            }
        ]
    };

    var fieldActivities = [
        {
            id: "FLD-001", role: "dhun", type: "sowing",
            title: "Walk the rabi seedbed with the steward",
            produceId: "sarson", zone: "farms",
            date: dayAt(seedNow, 0, 7), status: "planned",
            notes: "Check the 4.5 ha block before the drill closes the sowing window.",
            visibility: "room", source: "programme", media: []
        },
        {
            id: "FLD-002", role: "dhun", type: "soil",
            title: "Seed lot check · RH-725",
            produceId: "sarson", zone: "farms",
            date: dayAt(seedNow, 1, 9), status: "planned",
            notes: "Germination sheet and a sample from the September lot.",
            visibility: "room", source: "programme", media: []
        },
        {
            id: "FLD-003", role: "dhun", type: "scouting",
            title: "Check the bajra drying yard",
            produceId: "bajra", zone: "farms",
            date: dayAt(seedNow, 2, 12), status: "planned",
            notes: "Moisture reading before the lot is bagged for the market.",
            visibility: "room", source: "programme", media: []
        },
        {
            id: "FLD-004", role: "dhun", type: "delivery",
            title: "Amla drying room handover",
            produceId: "amla", zone: "orchard",
            date: dayAt(seedNow, 3, 11), status: "planned",
            notes: "Hand the 600 kg batch to the kitchen after grading.",
            visibility: "room", source: "programme", media: []
        },
        {
            id: "FLD-005", role: "dhun", type: "review",
            title: "Weekly programme stand-up",
            produceId: "", zone: "kitchen",
            date: dayAt(seedNow, -1, 16), status: "done",
            notes: "Quorum queue, drying room and the nursery mulch window.",
            visibility: "room", source: "programme", media: []
        },
        {
            id: "FLD-006", role: "steward", type: "sowing",
            title: "Sow sarson block · 4.5 ha",
            produceId: "sarson", zone: "farms",
            date: dayAt(seedNow, 0, 6), status: "planned",
            notes: "Drill calibrated for the RH-725 lot. Twelve geotagged points required.",
            visibility: "room", source: "challenge", media: []
        },
        {
            id: "FLD-007", role: "steward", type: "irrigation",
            title: "Irrigate kitchen nursery beds",
            produceId: "microgreens", zone: "kitchen",
            date: dayAt(seedNow, 1, 6), status: "planned",
            notes: "Hold the water buffer; no borewell pumping during covenant hours.",
            visibility: "room", source: "programme", media: []
        },
        {
            id: "FLD-008", role: "steward", type: "harvest",
            title: "Selective amla harvest · 40 trees",
            produceId: "amla", zone: "orchard",
            date: dayAt(seedNow, 2, 7), status: "planned",
            notes: "Leave the north-edge fruit and retain 20% on every third tree.",
            visibility: "room", source: "challenge", media: []
        },
        {
            id: "FLD-009", role: "steward", type: "compost",
            title: "Turn compost windrows",
            produceId: "", zone: "farms",
            date: dayAt(seedNow, -2, 15), status: "done",
            notes: "Second turn complete. Temperature log filed with the soil panel.",
            visibility: "room", source: "programme", media: []
        },
        {
            id: "FLD-010", role: "steward", type: "mulch",
            title: "Mulch the hedge line before the dry spell",
            produceId: "moringa", zone: "kitchen",
            date: dayAt(seedNow, 5, 8), status: "planned",
            notes: "Keep the 2 m no-till margin. Two water points stay clear.",
            visibility: "room", source: "programme", media: []
        },
        {
            id: "FLD-011", role: "funder", type: "review",
            title: "Covenant review · orchard edge",
            produceId: "amla", zone: "orchard",
            date: dayAt(seedNow, 4, 10), status: "planned",
            notes: "Review retained-fruit evidence before the next milestone release.",
            visibility: "room", source: "programme", media: []
        },
        {
            id: "FLD-012", role: "funder", type: "scouting",
            title: "Quarterly site walk",
            produceId: "", zone: "farms",
            date: dayAt(seedNow, -3, 9), status: "done",
            notes: "Bunds, pasture gap and the pump house. No covenant exceptions.",
            visibility: "room", source: "programme", media: []
        }
    ];

    var covenants = [
        {
            id: "COV-01",
            title: "Orchard nesting window",
            zone: "orchard",
            rule: "No mechanical harvest before 07:00 or after 18:00. Leave 20% fruit on every third marker tree.",
            metric: "20% fruit retained",
            progress: 0.72,
            status: "active"
        },
        {
            id: "COV-02",
            title: "Water buffer",
            zone: "farms",
            rule: "Keep 10% of channel flow in the recharge pond. No borewell pumping during covenant hours.",
            metric: "58% of buffer target",
            progress: 0.58,
            status: "active"
        },
        {
            id: "COV-03",
            title: "Habitat hedge",
            zone: "kitchen",
            rule: "Plant 300 native saplings; no till within 2 m of the strip. Two water points, no pesticide drift.",
            metric: "34% established",
            progress: 0.34,
            status: "draft"
        }
    ];

    var zonePressure = {
        farms: { pressure: 0.62, water: 0.41, habitat: 0.18, note: "Rabi sowing pressure · water buffer improving" },
        orchard: { pressure: 0.48, water: 0.55, habitat: 0.41, note: "Nesting window · 20% fruit retention" },
        kitchen: { pressure: 0.38, water: 0.33, habitat: 0.29, note: "Hedge draft · no-till margin staked" },
        dairy: { pressure: 0.27, water: 0.46, habitat: 0.36, note: "Fodder rotation · low harvest pressure" }
    };

    return {
        schema: SCHEMA,
        seededAt: seedNow,
        activeRole: "funder",
        mode: "REHEARSAL",
        token: {
            symbol: "DHN",
            name: "Dhun Commons",
            floorINR: 10,
            issued: 150000,
            fiatReserve: 1500000,
            fiatRaised: 420000,
            quorum: 2,
            members: 3,
            allowance: 500,
            conservationPct: 8,
            chain: "LEZ testnet 0.4",
            program: "dhun_commons::multisig",
            version: "0.1.0",
            imageId: "pending M0",
            registry: "dhun_commons.registry.v1",
            mode: "REHEARSAL"
        },
        roles: roles,
        wallets: wallets,
        proposals: proposals,
        ledger: ledger,
        offers: offers,
        fieldActivities: fieldActivities,
        fieldOrders: [],
        projects: projects,
        challenges: challenges,
        channels: channels,
        messages: messages,
        covenants: covenants,
        zonePressure: zonePressure,
        room: {
            active: "room-msig",
            binding: "Rehearsal rooms · production uses a signed LEZ-to-Chat identity binding",
            transport: "Local preview · production: Logos Chat E2EE"
        },
        policy: {
            propose: "Any current member",
            approve: "Distinct current member",
            execute: "Any current member after quorum",
            timelockRecommended: 1800,
            timelockCurrent: 0,
            posture: "Private by default · public posture operator-selectable",
            disclosure: "Encrypted checkpoint package to a named auditor or DAO audience",
            audit: "Tier-1 audit required before mainnet recommendation",
            licence: "MIT OR Apache-2.0"
        }
    };
}
