import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme
import "../components"

Item {
    id: page
    objectName: "casePage"

    signal navigate(string pageKey)

    readonly property string caseUrl: "https://the-500-acre-proof-atecxfewqi9.qoder.website/"
    readonly property color plum: "#5E2A7D"
    readonly property color plumSoft: "#EDE4F1"
    readonly property color casePaper: "#F7F6F1"
    readonly property color caseInk: "#14120E"

    property int modelAcres: 300

    readonly property real produceValue: modelAcres * 80000
    readonly property real inventoryLoss: produceValue * 0.09
    readonly property real financeDrag: produceValue * 0.45 * 0.14 * (120 / 365)
    readonly property real planningLeak: produceValue * 0.03
    readonly property real certRisk: produceValue * 0.06
    readonly property real totalStake: inventoryLoss + financeDrag + planningLeak + certRisk
    readonly property real addressable: totalStake * 0.4
    readonly property real perAcre: totalStake / modelAcres
    readonly property real maxStake: inventoryLoss

    readonly property var minuteBeats: [
        { tag: "What", body: "A private supply-chain stack for 500 working acres — field to lot to kitchen to buyer, with one lot record and a three-party release." },
        { tag: "Why", body: "The harvest is real; the proof is not. Every handoff loses value that the people who work the land pay for first." },
        { tag: "How", body: "A Basecamp module on the user’s machine, Logos Messaging and LEZ underneath, local state by default. Privacy is the condition, not a feature." },
        { tag: "Who", body: "Dhun Field Unit, Khejri Mandal stewards, Dhun Capital Circle, the kitchen, a neighbouring cooperative — built by Abhinav Dey." }
    ]

    readonly property var problems: [
        { number: "01", tag: "Inventory", title: "What exists, where, and how much?", body: "No single lot record runs from field to store to kitchen to market. Spoilage, double-selling and phantom stock hide in the gap.", cost: "₹1.53 lakh crore", note: "of food lost after harvest in India each year." },
        { number: "02", tag: "Financing", title: "The harvest is collateral. The record is not.", body: "Lenders price opacity as risk. Growers borrow short, sell early, and hand over the only book they have just to be believed.", cost: "33%", note: "of outstanding agricultural credit is non-institutional." },
        { number: "03", tag: "Enterprise planning", title: "Every season is replanned from memory.", body: "Field work, kitchen demand, project bids and certification evidence sit in different systems, owned by different people, with no shared version of the plan.", cost: "€1,600–3,000", note: "to certify organic coffee per group in Kenya, over a three-year conversion." },
        { number: "04", tag: "Market access", title: "Certified does not mean sold.", body: "A sticker without demand is a cost, not a premium. The paperwork is real; the buyer is not guaranteed.", cost: "60–67%", note: "of compliant cocoa sold without the certified premium." }
    ]

    readonly property var certCosts: [
        { label: "Organic coffee, Kenya", value: "€1,600–3,000" },
        { label: "Conversion period", value: "3 years" },
        { label: "Cocoa audit, 1,000 producers", value: "$7.5–8.5 / farmer" },
        { label: "Fairtrade group, initial", value: "≈$9,150" },
        { label: "Upfront certification", value: "€87–215 / ha" }
    ]

    readonly property var stackRows: [
        { number: "01", title: "Field & identity", body: "Satellite field map, four zones, produce lots, field calendar, steward profiles and weather advisory.", tone: "real", status: "Real", tags: "Basecamp runtime" },
        { number: "02", title: "Inventory", body: "Seeded lots, quantities, prices, market stock, kitchen coverage and shortfall lines. One lot ID can travel from field to plate.", tone: "real", status: "Real logic", tags: "Local state" },
        { number: "03", title: "Planning", body: "Kitchen planner from a dish, mood or menu; seasonal calendar; weather-led field windows; project bids and short cultivation challenges.", tone: "real", status: "Real logic", tags: "Deterministic" },
        { number: "04", title: "Finance", body: "2-of-3 proposal queue, decode-before-sign, escrow, milestone releases, external sale and conservation covenant.", tone: "partial", status: "Partial", tags: "LEZ testnet" },
        { number: "05", title: "Market & traceability", body: "Listings, offers, purchases, batch handover and provenance. The buyer sees the lot, not the farm’s whole book.", tone: "partial", status: "Partial", tags: "Local flow" },
        { number: "06", title: "Coordination & evidence", body: "Encrypted room, Logos Messaging, Telegram relay, local assistant and milestone evidence. SHA-256 anchors today; CID storage next.", tone: "partial", status: "Partial", tags: "Messaging" }
    ]

    readonly property var loopSteps: [
        { number: "01", title: "Report", body: "A steward records lot, quantity and reporter. The report is hashed." },
        { number: "02", title: "Confirm", body: "The field unit confirms the same lot on a separate device." },
        { number: "03", title: "Release", body: "Funder and steward both sign. The treasury releases escrow." },
        { number: "04", title: "Receipt", body: "A portable JSON receipt carries both signatures and a second hash." }
    ]

    readonly property var modules: [
        { label: "Field map", key: "field", note: "lots, calendar, studio" },
        { label: "Kitchen", key: "kitchen", note: "dish → sourcing" },
        { label: "Treasury", key: "wallet", note: "2-of-3 releases" },
        { label: "Room", key: "room", note: "Logos Messaging" },
        { label: "Landscape", key: "landscape", note: "seasonal catalogue" }
    ]

    readonly property var milestones: [
        { id: "M1", window: "0–3 months", amount: "$25k", title: "Pilot hardening", body: "20 farmers, 3 crops, offline-first records, local-language labels, QR lot cards, a written threat model and an external review." },
        { id: "M2", window: "3–9 months", amount: "$60k", title: "Trust & finance", body: "CID evidence storage, selective-disclosure proofs, milestone escrow, one buyer and one lender integration, certification export." },
        { id: "M3", window: "9–18 months", amount: "$90k", title: "Scale & governance", body: "A three-village federation, operator training, module registry publication, soil and biodiversity metrics, a non-token revenue model." }
    ]

    readonly property var sources: [
        { n: "01", text: "Post-harvest loss, India — ₹1.53 lakh crore a year. NABCONS for MoFPI, cited in Gulati et al., ICRIER Policy Brief 20 (2024).", url: "https://icrier.org/pdf/Policy_Brief_20.pdf" },
        { n: "02", text: "Land degradation — 29.7% of India, ~97.85 Mha. ISRO Desertification and Land Degradation Atlas (2018/2021).", url: "https://vedas.sac.gov.in/content/vcms/atlas/dsm/Desertification_Land_Degradation_Atlas_2018_SAC_ISRO_Vol-2.pdf" },
        { n: "03", text: "2024 was India’s warmest year since 1901, +0.65°C. IMD Annual Climate Summary; WMO statement.", url: "https://wmo.int/media/news-from-members/statement-climate-of-india-during-2025" },
        { n: "04", text: "33% of outstanding agricultural credit is non-institutional. NSS 77th Round (2019); ISAE analysis.", url: "https://isaeindia.com/view-pdf/371" },
        { n: "05", text: "Solidaridad 2025 — 1.3M farmers with improved yields, 974,545 with higher income, 2.8M ha, €69.6M income. Solidaridad Annual Report 2025.", url: "https://www.solidaridadnetwork.org/" },
        { n: "06", text: "Certification costs — Kenya organic coffee €1,600–3,000 (Solidaridad, 2020); cocoa audit $7.5–8.5/farmer (Giorgi, 2013); €87–215/ha (Oosterveer et al., 2016).", url: "" }
    ]

    function inr(value) {
        var v = Number(value) || 0;
        if (v >= 10000000) return "₹" + (v / 10000000).toFixed(2) + " Cr";
        if (v >= 100000) return "₹" + (v / 100000).toFixed(1) + " L";
        return "₹" + Math.round(v).toLocaleString(Qt.locale("en-IN"), "f", 0);
    }

    function count(value) {
        return Math.round(value).toLocaleString(Qt.locale("en-IN"), "f", 0);
    }

    function toneBg(tone) {
        if (tone === "real") return "#E4EFD3";
        if (tone === "partial") return "#F4E6C9";
        return "#F0E7DE";
    }

    function toneFg(tone) {
        if (tone === "real") return "#2C4A1E";
        if (tone === "partial") return "#7A541A";
        return "#6B5A4C";
    }

    function goTo(section) {
        if (!section) return;
        var y = section.y + content.y - 18;
        scroller.contentY = Math.max(0, Math.min(y, scroller.contentHeight - scroller.height));
    }

    function sectionAt(index) {
        if (index === 0) return minuteSec;
        if (index === 1) return problemSec;
        if (index === 2) return valueSec;
        if (index === 3) return certSec;
        if (index === 4) return whySec;
        if (index === 5) return stackSec;
        if (index === 6) return loopSec;
        if (index === 7) return planSec;
        return whoSec;
    }

    Rectangle {
        anchors.fill: parent
        color: page.casePaper
    }

    Flickable {
        id: scroller
        objectName: "caseScroller"
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight + 96
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: content
            x: Theme.pagePadding
            y: 24
            width: scroller.width - Theme.pagePadding * 2
            spacing: 0

            Rectangle {
                id: hero
                Layout.fillWidth: true
                Layout.preferredHeight: 520
                radius: Theme.radiusXL
                clip: true
                color: Theme.forest

                Image {
                    anchors.fill: parent
                    source: "../assets/dhun-satellite.jpg"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#0E2118D2" }
                        GradientStop { position: 0.42; color: "#0E211899" }
                        GradientStop { position: 1.0; color: "#0E2118FA" }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 170
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#000E2118" }
                        GradientStop { position: 1.0; color: "#F20E2118" }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 40
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "DHUN.LIFE · CHAK GULABPURA, JAIPUR"
                            color: "#C9D8BF"
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            font.letterSpacing: 1.8
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "26.7113° N · 75.5901° E"
                            color: "#93A88F"
                            font.family: Theme.monoFont
                            font.pixelSize: 8
                            font.letterSpacing: 0.6
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 16
                        Layout.preferredHeight: 1
                        color: "#3C5946"
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.topMargin: 8
                        text: "A CASE FOR A WORKING LANDSCAPE"
                        color: Theme.lime
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        font.letterSpacing: 2.2
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 14
                        text: "Five hundred acres\nalready produce."
                        color: "#F7F4E8"
                        font.family: Theme.displayFont
                        font.pixelSize: 48
                        font.letterSpacing: -1.2
                        lineHeight: 0.96
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "They cannot prove it."
                        color: Theme.lime
                        font.family: Theme.displayFont
                        font.pixelSize: 48
                        font.italic: true
                        font.letterSpacing: -1
                        lineHeight: 0.96
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 560
                        Layout.topMargin: 16
                        text: "A private, local-first supply-chain stack for Dhun’s landscape — built on Logos, informed by Zu-Grāma’s coordination logic, and rehearsed today in this app."
                        color: "#D2DCCB"
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                        lineHeight: 1.45
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.topMargin: 16
                        text: "A CASE BY ABHINAV DEY · BUILDER OF DHUN COMMONS"
                        color: "#C9D8BF"
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        font.letterSpacing: 1.8
                    }

                    RowLayout {
                        Layout.topMargin: 18
                        spacing: 10

                        Rectangle {
                            implicitWidth: readLabel.implicitWidth + 34
                            implicitHeight: 42
                            radius: 21
                            color: "#F7F4E8"

                            Text {
                                id: readLabel
                                anchors.centerIn: parent
                                text: "Read the case in 60 seconds"
                                color: Theme.forest
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.goTo(page.minuteSec)
                            }
                        }

                        Rectangle {
                            implicitWidth: loopLabel.implicitWidth + 32
                            implicitHeight: 42
                            radius: 21
                            color: "transparent"
                            border.width: 1
                            border.color: "#6C8774"

                            Text {
                                id: loopLabel
                                anchors.centerIn: parent
                                text: "Run the working loop ↗"
                                color: "#E8EFDF"
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally(page.caseUrl + "#loop")
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 40

                        Repeater {
                            model: [
                                { value: "500", label: "Acres" },
                                { value: "300,000", label: "Trees" },
                                { value: "3", label: "Parties" },
                                { value: "1", label: "Shared ledger" }
                            ]

                            delegate: ColumnLayout {
                                required property var modelData
                                spacing: 4

                                Text {
                                    text: modelData.value
                                    color: "#F7F4E8"
                                    font.family: Theme.displayFont
                                    font.pixelSize: 24
                                }

                                Text {
                                    text: modelData.label.toUpperCase()
                                    color: "#C9D8BF"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    font.letterSpacing: 1.6
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                columns: Math.max(3, Math.floor(width / 118))
                columnSpacing: 4
                rowSpacing: 2

                Repeater {
                    model: ["01 Minute", "02 Problem", "03 Value", "04 Proof", "05 Why Logos", "06 Stack", "07 The loop", "08 Adoption", "09 Who"]

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 6
                        color: indexMouse.containsMouse ? "#EFEADB" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.toUpperCase()
                            color: indexMouse.containsMouse ? page.plum : "#6C6758"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.letterSpacing: 1.3
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: indexMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.goTo(page.sectionAt(index))
                        }
                    }
                }
            }

            ColumnLayout {
                id: minuteSec
                Layout.fillWidth: true
                Layout.topMargin: 72
                spacing: 24

                CaseHead {
                    number: "01"
                    kicker: "The minute"
                    title: "The harvest is real."
                    accent: "The proof is not."
                    accentColor: page.plum
                    lede: "Dhun’s acres are a working landscape, not a spreadsheet. This is the sixty-second version: what we built, why the record breaks, how the stack fixes the handoff, and who carries it."
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 12

                    Repeater {
                        model: page.minuteBeats

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 176
                            radius: 16
                            color: "#FFFDF6"
                            border.width: 1
                            border.color: "#E1DCCB"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: String(index + 1).length < 2 ? "0" + (index + 1) : "" + (index + 1)
                                        color: page.plum
                                        font.family: Theme.monoFont
                                        font.pixelSize: 9
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: modelData.tag.toUpperCase()
                                        color: "#8A8474"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        font.letterSpacing: 1.6
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.body
                                    color: "#26352B"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    lineHeight: 1.45
                                    wrapMode: Text.WordWrap
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: problemSec
                Layout.fillWidth: true
                Layout.topMargin: 84
                spacing: 24

                CaseHead {
                    number: "02"
                    kicker: "The problem · Track A"
                    title: "The loss is not in the harvest."
                    accent: "It is in the handoffs."
                    accentColor: page.plum
                    lede: "The record breaks at every handoff: a paper register, a WhatsApp photo, a buyer’s memory. Four failures follow, and each one has a price."
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12

                    Repeater {
                        model: page.problems

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 252
                            radius: 18
                            color: "#FFFDF6"
                            border.width: 1
                            border.color: "#E1DCCB"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 24
                                spacing: 9

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Text {
                                        text: modelData.number
                                        color: page.plum
                                        font.family: Theme.monoFont
                                        font.pixelSize: 10
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: "#EBE5D6"
                                    }

                                    Text {
                                        text: modelData.tag.toUpperCase()
                                        color: "#8A8474"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        font.letterSpacing: 1.5
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: page.caseInk
                                    font.family: Theme.displayFont
                                    font.pixelSize: 22
                                    lineHeight: 1
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.body
                                    color: "#54625A"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                }

                                Item { Layout.fillHeight: true }

                                Text {
                                    text: modelData.cost
                                    color: Theme.clayDeep
                                    font.family: Theme.displayFont
                                    font.pixelSize: 24
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.note
                                    color: "#7A7566"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    lineHeight: 1.35
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: valueSec
                Layout.fillWidth: true
                Layout.topMargin: 84
                spacing: 24

                CaseHead {
                    number: "03"
                    kicker: "Value the issues"
                    title: "What opacity costs"
                    accent: "on 500 acres."
                    accentColor: page.plum
                    lede: "A transparent planning model, not Dhun’s audited accounts. Move the acres. The point is not the exact number; it is that every leak is large enough to fund the fix."
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 356
                    radius: Theme.radiusXL
                    color: Theme.forest

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 36
                        spacing: 44

                        ColumnLayout {
                            Layout.preferredWidth: 296
                            spacing: 0

                            Text {
                                text: "VALUE AT STAKE / YEAR"
                                color: Theme.lime
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                font.letterSpacing: 1.8
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.topMargin: 10
                                text: page.inr(page.totalStake)
                                color: "#F7F4E8"
                                font.family: Theme.displayFont
                                font.pixelSize: 46
                                font.letterSpacing: -1
                            }

                            Text {
                                text: (page.totalStake / page.produceValue * 100).toFixed(1) + "% of " + page.inr(page.produceValue) + " produce value"
                                color: "#A9BFA9"
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 22
                                Layout.preferredHeight: 1
                                color: "#2C4734"
                            }

                            Text {
                                Layout.topMargin: 18
                                text: "PRODUCTIVE ACRES"
                                color: "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                font.letterSpacing: 1.6
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 10

                                Text {
                                    text: page.count(page.modelAcres)
                                    color: "#F7F4E8"
                                    font.family: Theme.displayFont
                                    font.pixelSize: 24
                                }

                                Text {
                                    text: "of 500"
                                    color: "#8FA795"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.bottomMargin: 4
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: page.inr(page.perAcre) + " / acre"
                                    color: Theme.lime
                                    font.family: Theme.monoFont
                                    font.pixelSize: 9
                                }
                            }

                            Rectangle {
                                id: acresTrack
                                Layout.fillWidth: true
                                Layout.topMargin: 12
                                Layout.preferredHeight: 5
                                radius: 3
                                color: "#2C4734"

                                Rectangle {
                                    width: Math.max(0, Math.min(acresTrack.width, (page.modelAcres - 100) / 400 * acresTrack.width))
                                    height: parent.height
                                    radius: 3
                                    color: Theme.lime
                                }

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: Theme.lime
                                    x: Math.max(0, Math.min(acresTrack.width - 16, (page.modelAcres - 100) / 400 * acresTrack.width - 8))
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -12
                                    cursorShape: Qt.PointingHandCursor

                                    function setFrom(x) {
                                        var ratio = Math.max(0, Math.min(1, (x + 12) / acresTrack.width));
                                        page.modelAcres = Math.round((100 + ratio * 400) / 10) * 10;
                                    }

                                    onPressed: setFrom(mouse.x)
                                    onPositionChanged: {
                                        if (pressed) setFrom(mouse.x);
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 16
                                text: "Addressable at 40% recovery: " + page.inr(page.addressable) + ". A scenario, not a promise. No price premium is assumed."
                                color: "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                lineHeight: 1.4
                                wrapMode: Text.WordWrap
                            }

                            Item { Layout.fillHeight: true }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Repeater {
                                model: [
                                    { label: "Inventory loss", value: page.inventoryLoss, color: Theme.lime },
                                    { label: "Finance drag", value: page.financeDrag, color: "#E0B25C" },
                                    { label: "Planning leakage", value: page.planningLeak, color: "#C79A82" },
                                    { label: "Certification / premium", value: page.certRisk, color: "#C76B47" }
                                ]

                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: modelData.label
                                            color: "#C3D2C0"
                                            font.family: Theme.uiFont
                                            font.pixelSize: 11
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: page.inr(modelData.value)
                                            color: "#F7F4E8"
                                            font.family: Theme.monoFont
                                            font.pixelSize: 10
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 6
                                        radius: 3
                                        color: "#243C2C"

                                        Rectangle {
                                            width: parent.width * Math.max(0.02, modelData.value / page.maxStake)
                                            height: parent.height
                                            radius: 3
                                            color: modelData.color
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                Layout.preferredHeight: 1
                                color: "#2C4734"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 24

                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: "PER PRODUCTIVE ACRE"
                                        color: "#8FA795"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        font.letterSpacing: 1.4
                                    }
                                    Text {
                                        text: page.inr(page.perAcre)
                                        color: "#F7F4E8"
                                        font.family: Theme.displayFont
                                        font.pixelSize: 18
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: "ASSUMPTIONS"
                                        color: "#8FA795"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        font.letterSpacing: 1.4
                                    }
                                    Text {
                                        text: "₹80k/acre · 9% loss · 45% locked · 14% · 120 days · 3% · 6%"
                                        color: "#C3D2C0"
                                        font.family: Theme.monoFont
                                        font.pixelSize: 8
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }

            ColumnLayout {
                id: certSec
                Layout.fillWidth: true
                Layout.topMargin: 84
                spacing: 24

                CaseHead {
                    number: "04"
                    kicker: "What certification taught us"
                    title: "Solidaridad proved the demand for proof."
                    accent: "It also proved the cost."
                    accentColor: page.plum
                    lede: "The largest sustainability intermediaries are the best available stress test for any “certify the smallholder” pitch — including ours."
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 340
                        radius: 18
                        color: "#FFFDF6"
                        border.width: 1
                        border.color: "#E1DCCB"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 10

                            Text {
                                text: "WHAT THEY DID"
                                color: page.plum
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                font.letterSpacing: 1.8
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Training, audits, market linkages, traceability."
                                color: page.caseInk
                                font.family: Theme.displayFont
                                font.pixelSize: 22
                                lineHeight: 1.02
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Solidaridad supports producers across commodities and regions: farmer training, internal control systems, audit preparation, premium market access and regenerative standards. In 2025 it reported 1.3 million farmers with improved yields, 974,545 with higher farm income and 2.8 million hectares under sustainable management."
                                color: "#54625A"
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                lineHeight: 1.45
                                wrapMode: Text.WordWrap
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                Layout.fillWidth: true
                                text: "Programme-wide results, not certification-only effects. The distinction matters."
                                color: "#8A8474"
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.italic: true
                                lineHeight: 1.35
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 340
                        radius: 18
                        color: "#FBF7EC"
                        border.width: 1
                        border.color: "#DED5BE"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 8

                            Text {
                                text: "WHAT IT COST"
                                color: page.plum
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                font.letterSpacing: 1.8
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Front-loaded, per group, per audit."
                                color: page.caseInk
                                font.family: Theme.displayFont
                                font.pixelSize: 22
                                lineHeight: 1.02
                                wrapMode: Text.WordWrap
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 0

                                Repeater {
                                    model: page.certCosts

                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            color: "#54625A"
                                            font.family: Theme.uiFont
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: modelData.value
                                            color: page.caseInk
                                            font.family: Theme.monoFont
                                            font.pixelSize: 10
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 1
                                            Layout.alignment: Qt.AlignBottom
                                            color: "#E7DFCB"
                                            visible: false
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                Layout.fillWidth: true
                                text: "Sources: Solidaridad Kenya (2020), Giorgi (2013), Oosterveer et al. (2016)."
                                color: "#8A8474"
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                lineHeight: 1.35
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 340
                        radius: 18
                        color: "#FFFDF6"
                        border.width: 1
                        border.color: "#E1DCCB"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 10

                            Text {
                                text: "WHAT IT RETURNED"
                                color: page.plum
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                font.letterSpacing: 1.8
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Real, but demand-dependent."
                                color: page.caseInk
                                font.family: Theme.displayFont
                                font.pixelSize: 22
                                lineHeight: 1.02
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Annual benefit per farmer ranged from $13.4 under Fairtrade to $190.8 under Rainforest Alliance — but only when the premium was actually sold. Between 60% and 67% of compliant cocoa was sold without the certified premium."
                                color: "#54625A"
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                lineHeight: 1.45
                                wrapMode: Text.WordWrap
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                Layout.fillWidth: true
                                text: "At low yields, cost per tonne can exceed the premium. The sticker is not the business model."
                                color: "#8A8474"
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.italic: true
                                lineHeight: 1.35
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    radius: 16
                    color: page.plumSoft

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 28

                        Repeater {
                            model: [
                                { n: "01", text: "Lower the cost of evidence. Make the audit trail a by-product of daily work." },
                                { n: "02", text: "Make the premium traceable to a lot, a proof and a payment." },
                                { n: "03", text: "Do not invent a new sticker. Export evidence to existing demand." }
                            ]

                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: modelData.n
                                    color: page.plum
                                    font.family: Theme.monoFont
                                    font.pixelSize: 9
                                    Layout.alignment: Qt.AlignTop
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.text
                                    color: "#3E2B4A"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 11
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: whySec
                Layout.fillWidth: true
                Layout.topMargin: 84
                spacing: 24

                CaseHead {
                    number: "05"
                    kicker: "Why Logos × Zu-Grāma"
                    title: "Exit the platform."
                    accent: "Keep the coordination."
                    accentColor: page.plum
                    lede: "Logos is the protocol layer for private-by-default coordination. Zu-Grāma is the social layer that turns a pilot into a community. Dhun is the real local problem both need."
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 332
                        radius: 18
                        color: "#FFFDF6"
                        border.width: 1
                        border.color: "#E1DCCB"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 10

                            Text {
                                text: "LOGOS"
                                color: page.plum
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                font.letterSpacing: 1.9
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Build the parallel."
                                color: page.caseInk
                                font.family: Theme.displayFont
                                font.pixelSize: 24
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "A private-by-default technology stack for parallel societies: local Basecamp runtime, content-addressed storage, private messaging, privacy-preserving blockchain (LEZ), and a discovery, peering and mixnet layer. 151 contributors, 226 node operators, 47 circles, 19 winnable issues."
                                color: "#54625A"
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                lineHeight: 1.45
                                wrapMode: Text.WordWrap
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 3
                                    color: page.plum
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 5
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Privacy is the condition that makes free association possible."
                                    color: "#3E4C43"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 3
                                    color: page.plum
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 5
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Run the stack on your own hardware, under your own keys."
                                    color: "#3E4C43"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: 300
                        Layout.preferredHeight: 300
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            x: 66; y: 4; width: 168; height: 168; radius: 84
                            color: "#44D9EF92"
                            border.width: 1
                            border.color: "#9CBB4D"
                        }

                        Rectangle {
                            x: 0; y: 88; width: 168; height: 168; radius: 84
                            color: "#2E5E2A7D"
                            border.width: 1
                            border.color: "#8E6BA1"
                        }

                        Rectangle {
                            x: 132; y: 88; width: 168; height: 168; radius: 84
                            color: "#33E0B25C"
                            border.width: 1
                            border.color: "#C79A4F"
                        }

                        Text {
                            x: 84; y: 56; width: 132
                            horizontalAlignment: Text.AlignHCenter
                            text: "DHUN\nland · food · people"
                            color: "#3B4A2A"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.letterSpacing: 0.8
                            lineHeight: 1.3
                        }

                        Text {
                            x: 10; y: 206; width: 148
                            horizontalAlignment: Text.AlignHCenter
                            text: "LOGOS\nprivacy · protocol"
                            color: "#4A2F55"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.letterSpacing: 0.8
                            lineHeight: 1.3
                        }

                        Text {
                            x: 142; y: 206; width: 148
                            horizontalAlignment: Text.AlignHCenter
                            text: "ZU-GRĀMA\ncoordination · capital"
                            color: "#6B4B16"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.letterSpacing: 0.8
                            lineHeight: 1.3
                        }

                        Rectangle {
                            x: 104; y: 118; width: 92; height: 92; radius: 46
                            color: Theme.forest

                            Text {
                                anchors.centerIn: parent
                                width: 76
                                horizontalAlignment: Text.AlignHCenter
                                text: "FIELD-LEVEL\nSOVEREIGNTY"
                                color: Theme.lime
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                font.letterSpacing: 0.8
                                lineHeight: 1.25
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 332
                        radius: 18
                        color: "#FFFDF6"
                        border.width: 1
                        border.color: "#E1DCCB"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 10

                            Text {
                                text: "ZU-GRĀMA"
                                color: page.plum
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                font.letterSpacing: 1.9
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "An experiment in human interaction & organization."
                                color: page.caseInk
                                font.family: Theme.displayFont
                                font.pixelSize: 22
                                lineHeight: 1.02
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "A six-week pop-up village in Kerala (5 Jan–16 Feb 2025), 150–300 residents, built around five innovation levers: ambition, talent, capital, regulation and education. Tracks included governance, public goods, DeSci, deep tech, AI and cryptography."
                                color: "#54625A"
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                lineHeight: 1.45
                                wrapMode: Text.WordWrap
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 3
                                    color: page.plum
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 5
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Self-organized, decentralized community — not a conference."
                                    color: "#3E4C43"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 3
                                    color: page.plum
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 5
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Truth-seeking and quick feedback loops over scale for its own sake."
                                    color: "#3E4C43"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: stackSec
                Layout.fillWidth: true
                Layout.topMargin: 84
                spacing: 24

                CaseHead {
                    number: "06"
                    kicker: "The stack, end to end"
                    title: "One lot. Six layers."
                    accent: "No central owner."
                    accentColor: page.plum
                    lede: "This is the supply-chain stack we actually built in this app, mapped to the Logos primitives it uses or will use. The status tags are deliberate: real, partial, roadmap."
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 0

                    Repeater {
                        model: page.stackRows

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 92
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.topMargin: 16
                                anchors.bottomMargin: 16
                                spacing: 18

                                Text {
                                    Layout.preferredWidth: 26
                                    Layout.alignment: Qt.AlignTop
                                    text: modelData.number
                                    color: page.plum
                                    font.family: Theme.monoFont
                                    font.pixelSize: 9
                                }

                                Text {
                                    Layout.preferredWidth: 158
                                    Layout.alignment: Qt.AlignTop
                                    text: modelData.title
                                    color: page.caseInk
                                    font.family: Theme.displayFont
                                    font.pixelSize: 17
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    text: modelData.body
                                    color: "#54625A"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 11
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 112
                                    spacing: 5

                                    Rectangle {
                                        implicitWidth: statusLabel.implicitWidth + 16
                                        implicitHeight: 21
                                        radius: 10.5
                                        color: page.toneBg(modelData.tone)

                                        Text {
                                            id: statusLabel
                                            anchors.centerIn: parent
                                            text: modelData.status
                                            color: page.toneFg(modelData.tone)
                                            font.family: Theme.uiFont
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Text {
                                        text: modelData.tags
                                        color: "#8A8474"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 9
                                    }
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: "#E1DCCB"
                                visible: modelData.number !== "06"
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: loopSec
                Layout.fillWidth: true
                Layout.topMargin: 84
                spacing: 24

                CaseHead {
                    number: "07"
                    kicker: "The working loop · Track A + B"
                    title: "Report, confirm, release,"
                    accent: "keep the receipt."
                    accentColor: page.plum
                    lede: "One full loop an affected person can run and verify. The browser edition of this app runs the same loop, with a real SHA-256 digest and a downloadable receipt."
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.preferredHeight: 320
                    radius: Theme.radiusXL
                    color: Theme.forest

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 34
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 18

                            Repeater {
                                model: page.loopSteps

                                delegate: RowLayout {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: 14

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        RowLayout {
                                            spacing: 8
                                            Text {
                                                text: modelData.number
                                                color: Theme.lime
                                                font.family: Theme.monoFont
                                                font.pixelSize: 9
                                            }
                                            Rectangle {
                                                width: 28
                                                height: 1
                                                color: "#3C5946"
                                            }
                                        }

                                        Text {
                                            text: modelData.title
                                            color: "#F7F4E8"
                                            font.family: Theme.displayFont
                                            font.pixelSize: 22
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.body
                                            color: "#A9BFA9"
                                            font.family: Theme.uiFont
                                            font.pixelSize: 10
                                            lineHeight: 1.4
                                            wrapMode: Text.WordWrap
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        visible: index < 3
                                        text: "→"
                                        color: "#5C7862"
                                        font.family: Theme.displayFont
                                        font.pixelSize: 18
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 26
                            Layout.preferredHeight: 1
                            color: "#2C4734"
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 18
                            text: "In this app the treasury is a 2-of-3 state machine and the escrow balance is rehearsal DHN. The web edition adds a real SHA-256 report hash, two role signatures and a portable JSON receipt. Neither claims chain finality."
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            lineHeight: 1.45
                            wrapMode: Text.WordWrap
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 16
                            spacing: 10

                            Rectangle {
                                implicitWidth: browserLabel.implicitWidth + 34
                                implicitHeight: 40
                                radius: 20
                                color: Theme.lime

                                Text {
                                    id: browserLabel
                                    anchors.centerIn: parent
                                    text: "Open the browser loop ↗"
                                    color: Theme.forest
                                    font.family: Theme.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally(page.caseUrl + "#loop")
                                }
                            }

                            Rectangle {
                                implicitWidth: treasuryLabel.implicitWidth + 32
                                implicitHeight: 40
                                radius: 20
                                color: "transparent"
                                border.width: 1
                                border.color: "#5C7862"

                                Text {
                                    id: treasuryLabel
                                    anchors.centerIn: parent
                                    text: "Open the treasury here"
                                    color: "#E8EFDF"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.navigate("wallet")
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 10

                    Text {
                        text: "WHERE THIS LIVES TODAY"
                        color: "#6C6758"
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        font.letterSpacing: 1.8
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: page.modules

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 72
                                radius: 14
                                color: moduleMouse.containsMouse ? "#FFFDF6" : "transparent"
                                border.width: 1
                                border.color: "#DDD7C6"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 2

                                    Text {
                                        text: modelData.label
                                        color: page.caseInk
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.note
                                        color: "#8A8474"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }

                                    Item { Layout.fillHeight: true }

                                    Text {
                                        text: "Open →"
                                        color: page.plum
                                        font.family: Theme.uiFont
                                        font.pixelSize: 9
                                    }
                                }

                                MouseArea {
                                    id: moduleMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.navigate(modelData.key)
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: planSec
                Layout.fillWidth: true
                Layout.topMargin: 84
                spacing: 24

                CaseHead {
                    number: "08"
                    kicker: "Path to adoption"
                    title: "Who runs it"
                    accent: "when we leave."
                    accentColor: page.plum
                    lede: "Adoption is not a download. It is a named operator, a weekly ritual, and a route into the institutions that already touch the farm."
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Repeater {
                        model: [
                            { role: "Field operations", title: "Dhun Field Unit", body: "Owns the field ledger, the calendar, lot IDs and the weekly review. Runs the first-line dispute process." },
                            { role: "Steward governance", title: "Khejri Mandal", body: "Onboards stewards, reviews evidence, signs releases and represents field workers in the monthly council." },
                            { role: "Capital & covenant", title: "Dhun Capital Circle", body: "Holds the funder key, approves milestone releases and protects the conservation reserve." }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 154
                            radius: 16
                            color: "#FFFDF6"
                            border.width: 1
                            border.color: "#E1DCCB"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 6

                                Text {
                                    text: modelData.role.toUpperCase()
                                    color: "#8A8474"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    font.letterSpacing: 1.4
                                }

                                Text {
                                    text: modelData.title
                                    color: page.caseInk
                                    font.family: Theme.displayFont
                                    font.pixelSize: 18
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.body
                                    color: "#54625A"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 12

                    Repeater {
                        model: page.milestones

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 184
                            radius: 16
                            color: "#FBF7EC"
                            border.width: 1
                            border.color: "#DED5BE"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 7

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData.id
                                        color: page.plum
                                        font.family: Theme.monoFont
                                        font.pixelSize: 9
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.window
                                        color: "#8A8474"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                    }

                                    Text {
                                        text: modelData.amount
                                        color: page.caseInk
                                        font.family: Theme.displayFont
                                        font.pixelSize: 16
                                    }
                                }

                                Text {
                                    text: modelData.title
                                    color: page.caseInk
                                    font.family: Theme.displayFont
                                    font.pixelSize: 19
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.body
                                    color: "#54625A"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: 14
                    color: Theme.forest

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 22
                        anchors.rightMargin: 22
                        spacing: 16

                        Text {
                            text: "GRANT REQUEST"
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.letterSpacing: 1.6
                        }

                        Text {
                            text: "$175k"
                            color: Theme.lime
                            font.family: Theme.displayFont
                            font.pixelSize: 24
                        }

                        Text {
                            text: "≈ ₹1.54 crore at ₹88/$"
                            color: "#A9BFA9"
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "No token sale. No land-title claim. No carbon-credit claim without independent verification."
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                        }
                    }
                }
            }

            ColumnLayout {
                id: whoSec
                Layout.fillWidth: true
                Layout.topMargin: 84
                spacing: 24

                CaseHead {
                    number: "09"
                    kicker: "Who"
                    title: "Abhinav Dey"
                    accent: ""
                    accentColor: page.plum
                    lede: ""
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 28

                    Rectangle {
                        Layout.preferredWidth: 104
                        Layout.preferredHeight: 104
                        radius: 52
                        color: page.plumSoft

                        Text {
                            anchors.centerIn: parent
                            text: "AD"
                            color: page.plum
                            font.family: Theme.displayFont
                            font.pixelSize: 34
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: "I build community spaces — the physical kind and the digital kind. Shared rooms where people gather, and now a village-scale commons. The through-line is coordination: how people who do not fully trust each other can still get something done."
                            color: page.caseInk
                            font.family: Theme.displayFont
                            font.pixelSize: 16
                            lineHeight: 1.35
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "The first kind taught me that trust is built in person. The second has to carry that trust across a handoff without asking anyone to become transparent. I built Dhun Commons in Basecamp — the field map and produce lots, the kitchen planner, the three-party treasury, the Logos Messaging room, the LEZ testnet panel, the assistant and the web edition — and wrote the limits down."
                            color: "#54625A"
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            lineHeight: 1.5
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Built with Logos Basecamp · LEZ testnet · Logos Messaging · Qt/QML · vanilla JS · Open-Meteo/Ventusky. Full CV and references on request."
                            color: "#8A8474"
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            lineHeight: 1.4
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 84
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "SOURCES & DATA NOTES"
                        color: "#6C6758"
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        font.letterSpacing: 1.8
                        font.weight: Font.DemiBold
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Every external number here is traceable."
                        color: "#8A8474"
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: page.sources

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            color: sourceMouse.containsMouse ? "#F1ECDF" : "transparent"
                            radius: 8

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 14

                                Text {
                                    Layout.preferredWidth: 22
                                    text: modelData.n
                                    color: page.plum
                                    font.family: Theme.monoFont
                                    font.pixelSize: 9
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.text
                                    color: "#54625A"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    lineHeight: 1.35
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    visible: modelData.url !== ""
                                    text: "Open ↗"
                                    color: page.plum
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                }
                            }

                            MouseArea {
                                id: sourceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: modelData.url !== ""
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally(modelData.url)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.preferredHeight: 1
                    color: "#DDD7C6"
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.rightMargin: 130
                    spacing: 14

                    Text {
                        Layout.fillWidth: true
                        text: "A case by Abhinav Dey · built on Logos Basecamp · 2026"
                        color: "#8A8474"
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                    }

                    Rectangle {
                        implicitWidth: fullLabel.implicitWidth + 28
                        implicitHeight: 36
                        radius: 18
                        color: page.plum

                        Text {
                            id: fullLabel
                            anchors.centerIn: parent
                            text: "Open the full case ↗"
                            color: "#F7F4E8"
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally(page.caseUrl)
                        }
                    }
                }
            }
        }
    }
}
