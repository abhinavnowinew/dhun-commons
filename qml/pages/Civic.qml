import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme
import "../civic.js" as Civic
import "../components"

Item {
    id: page

    property var app: null
    property real now: Date.now()
    property int seed: 1947
    property bool running: false
    property var sim: Civic.create(1947, 10)

    readonly property int month: new Date(now).getMonth() + 1
    readonly property var m: Civic.metrics(sim)
    readonly property var digest: Civic.digestToday(sim)
    readonly property var inbox: Civic.openAsks(sim)
    readonly property var batched: Civic.batchedAsks(sim)
    readonly property var reflections: Civic.latestReflections(sim)
    readonly property var feed: Civic.recentLog(sim, 36)
    readonly property var pairs: Civic.collabPairs(sim, 4)

    Component.onCompleted: page.sim = Civic.create(page.seed, page.month)

    Timer {
        interval: 1200
        repeat: true
        running: page.running && !page.sim.done
        onTriggered: page.step()
    }

    function step() {
        if (page.sim.done) {
            page.running = false;
            return;
        }
        page.sim = Civic.advance(Civic.clone(page.sim));
        if (page.sim.done) page.running = false;
    }

    function runDay() {
        page.running = false;
        var guard = 0;
        do {
            page.sim = Civic.advance(Civic.clone(page.sim));
            guard += 1;
        } while (!page.sim.done && page.sim.phase !== "dawn" && guard < 12);
    }

    function reset() {
        page.running = false;
        page.seed = page.seed + 1;
        page.sim = Civic.create(page.seed, page.month);
    }

    function signAsk(id) {
        page.sim = Civic.sign(Civic.clone(page.sim), id);
    }

    function declineAsk(id) {
        page.sim = Civic.decline(Civic.clone(page.sim), id);
    }

    function budgetFraction() {
        return Math.min(1, Math.max(0, page.m.spent / page.sim.budget.pool));
    }

    function phaseIndex() {
        return Civic.PHASES.indexOf(page.sim.phase);
    }

    function humanDelay(value) {
        return value <= 0 ? "same day" : value + " day(s)";
    }

    function toneInk(tone) {
        if (tone === "good") return "#3F5A26";
        if (tone === "warn") return Theme.goldDeep;
        if (tone === "bad") return Theme.danger;
        return Theme.inkSoft;
    }

    function statusTone(status) {
        if (status === "awaiting") return { fg: Theme.goldDeep, bg: Theme.goldLight };
        if (status === "actioned") return { fg: "#3F5A26", bg: Theme.sageLight };
        if (status === "assigned") return { fg: "#3F5C6B", bg: Theme.blueLight };
        if (status === "closed") return { fg: "#3F5A26", bg: Theme.sageLight };
        return { fg: Theme.muted, bg: Theme.paperDeep };
    }

    function askTone(reason) {
        if (reason === "treasury") return { fg: Theme.goldDeep, bg: Theme.goldLight, edge: Theme.gold };
        if (reason === "permit") return { fg: "#3F5C6B", bg: Theme.blueLight, edge: Theme.blue };
        if (reason === "safety-critical") return { fg: Theme.danger, bg: Theme.clayLight, edge: Theme.danger };
        if (reason === "rights") return { fg: Theme.clayDeep, bg: Theme.clayLight, edge: Theme.clay };
        return { fg: Theme.muted, bg: Theme.paperDeep, edge: Theme.line };
    }

    function personaDomain(persona) {
        for (var i = 0; i < Civic.DOMAINS.length; ++i) {
            if (Civic.DOMAINS[i].guardian === persona.id) return Civic.DOMAINS[i];
        }
        for (var j = 0; j < Civic.DOMAINS.length; ++j) {
            if (persona.capability[Civic.DOMAINS[j].id] >= 2) return Civic.DOMAINS[j];
        }
        return Civic.DOMAINS[0];
    }

    function personaLoad(persona) {
        var active = 0;
        var closedToday = 0;
        var issues = page.sim.issues || [];
        for (var i = 0; i < issues.length; ++i) {
            var issue = issues[i];
            if (issue.owner !== persona.id) continue;
            if (issue.status === "assigned" || issue.status === "awaiting" || issue.status === "actioned") active += 1;
            if (issue.closedDay === page.sim.day) closedToday += 1;
        }
        return { active: active, closedToday: closedToday };
    }

    function personaStatus(persona) {
        var load = personaLoad(persona);
        if (load.active > 0) return load.active + " in hand" + (load.closedToday > 0 ? " · " + load.closedToday + " closed today" : "");
        if (load.closedToday > 0) return load.closedToday + " closed today · resting";
        return "Idle · next scan";
    }

    function personaMinutes(persona) {
        var minutes = 0;
        var issues = page.sim.issues || [];
        for (var i = 0; i < issues.length; ++i) {
            if (issues[i].owner === persona.id && issues[i].status === "closed") minutes += issues[i].humanMinutes;
        }
        return minutes;
    }

    function personaHours(persona) {
        return Math.round(personaMinutes(persona) / 6) / 10;
    }

    function peerLine(persona) {
        var peers = Civic.personaPeers(page.sim, persona.id, 2);
        if (!peers.length) return "No peer link yet";
        var parts = [];
        for (var i = 0; i < peers.length; ++i)
            parts.push(Civic.personaById(peers[i].persona).agent + " ×" + peers[i].total);
        return "with " + parts.join(" · ");
    }

    function pairLine(pair) {
        var parts = [];
        if (pair.joint) parts.push(pair.joint + " paired");
        if (pair.reviews) parts.push(pair.reviews + " checks");
        if (pair.consults) parts.push(pair.consults + " consults");
        if (pair.handoffs) parts.push(pair.handoffs + " handoffs");
        return Civic.personaById(pair.a).agent + " × " + Civic.personaById(pair.b).agent
                + " — " + parts.join(", ");
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight + 60
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: content
            x: Theme.pagePadding
            y: 24
            width: scroller.width - Theme.pagePadding * 2
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    spacing: 3

                    Text {
                        text: "Civic simulation"
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 24
                    }

                    Text {
                        text: "Eight residents, eight steward agents · water, roads, agri, safety, waste and care · they consult, pair, hand off and peer-check · synthetic seven-day run"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                    }
                }

                Item { Layout.fillWidth: true }

                Pill {
                    text: page.sim.done ? "horizon reached" : (page.running ? "agents working" : "paused")
                    fg: page.sim.done ? Theme.muted : (page.running ? "#3F5A26" : Theme.goldDeep)
                    bg: page.sim.done ? Theme.paperDeep : (page.running ? Theme.sageLight : Theme.goldLight)
                    dotColor: page.running ? "#5C7A3F" : (page.sim.done ? Theme.mutedLight : Theme.gold)
                }

                Pill {
                    text: "seed " + page.sim.seed
                    fg: Theme.muted
                    bg: Theme.paperDeep
                }

                ActionButton {
                    text: page.running ? "Pause" : (page.sim.done ? "Finished" : "Start")
                    variant: "primary"
                    compact: true
                    enabled: !page.sim.done
                    onClicked: page.running = !page.running
                }

                ActionButton {
                    text: "Run day"
                    variant: "secondary"
                    compact: true
                    enabled: !page.sim.done && !page.running
                    onClicked: page.runDay()
                }

                ActionButton {
                    text: "Reset"
                    variant: "ghost"
                    compact: true
                    onClicked: page.reset()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: clockBody.implicitHeight + 28
                radius: Theme.radiusLarge
                color: Theme.white
                border.width: 1
                border.color: Theme.line

                ColumnLayout {
                    id: clockBody
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "DAY " + page.sim.day + " OF " + page.sim.horizon
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.letterSpacing: 1.5
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: Civic.PHASE_LABEL[page.sim.phase]
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Pill {
                            text: Civic.PHASE_HINT[page.sim.phase]
                            fg: Theme.muted
                            bg: Theme.paperWarm
                            fontSize: 8
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: page.m.spent + " / " + page.sim.budget.pool + " DHN committed"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 5
                        radius: 2.5
                        color: Theme.paperDeep

                        Rectangle {
                            width: parent.width * page.budgetFraction()
                            height: parent.height
                            radius: parent.radius
                            color: page.budgetFraction() > 0.85 ? Theme.clay : Theme.forest
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Repeater {
                            model: Civic.PHASES

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool current: page.sim.phase === modelData
                                readonly property bool past: index < page.phaseIndex()

                                Layout.fillWidth: true
                                implicitHeight: 26
                                radius: 13
                                color: current ? Theme.forest : (past ? Theme.sageLight : "transparent")
                                border.width: current ? 0 : 1
                                border.color: past ? Theme.sage : Theme.line

                                Text {
                                    anchors.centerIn: parent
                                    text: Civic.PHASE_LABEL[modelData]
                                    color: current ? "#F4F7E9" : (past ? "#3F5A26" : Theme.mutedLight)
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    font.weight: current ? Font.DemiBold : Font.Normal
                                }
                            }
                        }
                    }

                    Text {
                        visible: page.digest !== null
                        Layout.fillWidth: true
                        text: page.digest
                              ? "Dusk " + page.digest.day + " · " + page.digest.closed + " closed · "
                                + page.digest.actions + " action(s) · " + page.digest.humanHours + " h returned"
                                + (page.digest.reopened > 0 ? " · " + page.digest.reopened + " reopened" : "")
                              : ""
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StatTile {
                    Layout.fillWidth: true
                    label: "OPEN NOW"
                    value: String(page.m.open)
                    caption: page.m.asks + " waiting on you · " + page.m.parked + " parked"
                    accent: Theme.clay
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "CLOSED WITH EVIDENCE"
                    value: String(page.m.closed)
                    caption: "Trust " + Math.round(page.m.trust * 100) + "% · median "
                             + page.humanDelay(page.m.medianResponse)
                    accent: Theme.limeDeep
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "HUMAN HOURS RETURNED"
                    value: String(page.m.humanHours)
                    caption: "Coordination absorbed across the run"
                    accent: Theme.gold
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "ASKS FOR YOU"
                    value: String(page.m.asks)
                    caption: page.m.batched + " held for tomorrow's digest"
                    accent: Theme.danger
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "CIVIC BUDGET LEFT"
                    value: String(page.m.left)
                    caption: page.m.spent + " DHN committed of 4,800"
                    accent: "#5A7684"
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "COVERAGE TODAY"
                    value: page.m.coverage + " / 6"
                    caption: "Domains actioned · " + page.m.links + " links"
                    accent: Theme.forestMid
                }
            }

            Text {
                text: "YOUR INBOX"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
                font.letterSpacing: 1.6
                font.weight: Font.DemiBold
                Layout.topMargin: 4
            }

            Rectangle {
                visible: page.inbox.length === 0
                Layout.fillWidth: true
                implicitHeight: quietBody.implicitHeight + 26
                radius: Theme.radiusMedium
                color: Theme.sageLight
                border.width: 1
                border.color: Theme.sage

                ColumnLayout {
                    id: quietBody
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 4

                    Text {
                        text: page.sim.done
                              ? "Nothing needs you here. The seven-day run is complete."
                              : "Nothing needs you right now."
                        color: "#3F5A26"
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.sim.done
                              ? "Reset with a new seed to watch the agents carry another week."
                              : "The agents are working the board. You only get pulled in for money, permits, safety-critical calls or repeated evidence gaps."
                        color: "#4C5F35"
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                    }
                }
            }

            ColumnLayout {
                visible: page.inbox.length > 0
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: page.inbox

                    delegate: Rectangle {
                        required property var modelData
                        readonly property var tone: page.askTone(modelData.reason)

                        Layout.fillWidth: true
                        implicitHeight: askBody.implicitHeight + 30
                        radius: Theme.radiusMedium
                        color: Theme.white
                        border.width: 1
                        border.color: tone.edge

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                width: 3
                                height: askBody.implicitHeight
                                radius: 1.5
                                color: tone.edge
                            }

                            ColumnLayout {
                                id: askBody
                                Layout.fillWidth: true
                                spacing: 5

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 7

                                    Pill {
                                        text: Civic.reasonLabel(modelData.reason)
                                        fg: tone.fg
                                        bg: tone.bg
                                        strong: true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        color: Theme.ink
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "by day " + modelData.deadline
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.ask
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.consequence
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    wrapMode: Text.WordWrap
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.cost + " DHN · held by "
                                              + Civic.actorLabel(modelData.persona).split(" · ")[0]
                                        color: Theme.mutedLight
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                    }

                                    ActionButton {
                                        text: "Decline"
                                        variant: "ghost"
                                        compact: true
                                        onClicked: page.declineAsk(modelData.id)
                                    }

                                    ActionButton {
                                        text: "Sign & clear"
                                        variant: "primary"
                                        compact: true
                                        onClicked: page.signAsk(modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: page.batched.length > 0
                Layout.fillWidth: true
                text: page.batched.length + " more ask(s) held for tomorrow's digest — one human, one bundle."
                color: Theme.goldDeep
                font.family: Theme.uiFont
                font.pixelSize: 9
            }

            Text {
                text: "AGENTS ON THE DESK"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
                font.letterSpacing: 1.6
                font.weight: Font.DemiBold
                Layout.topMargin: 4
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 10
                rowSpacing: 10

                Repeater {
                    model: Civic.PERSONAS

                    delegate: Rectangle {
                        required property var modelData
                        readonly property var domain: page.personaDomain(modelData)

                        Layout.fillWidth: true
                        implicitHeight: 138
                        radius: Theme.radiusMedium
                        color: Theme.white
                        border.width: 1
                        border.color: Theme.line

                        ColumnLayout {
                            id: agentBody
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 9
                                    color: domain.color

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.agent.slice(0, 2).toUpperCase()
                                        color: "#F7F4E8"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        text: modelData.agent + " · " + modelData.name
                                        color: Theme.ink
                                        font.family: Theme.uiFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.role + " · " + domain.short
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: page.personaStatus(modelData)
                                color: Theme.inkSoft
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                            }

                            Text {
                                Layout.fillWidth: true
                                text: page.peerLine(modelData)
                                color: Theme.mutedLight
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "≈ " + page.personaHours(modelData) + " h returned"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                }

                                Item { Layout.fillWidth: true }

                                Pill {
                                    text: modelData.hoursWeek + " h/wk cap"
                                    fg: Theme.muted
                                    bg: Theme.paperWarm
                                    fontSize: 8
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: interplayBody.implicitHeight + 26
                radius: Theme.radiusLarge
                color: Theme.paperWarm
                border.width: 1
                border.color: Theme.line

                ColumnLayout {
                    id: interplayBody
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 7

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "CREW INTERPLAY"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.letterSpacing: 1.6
                            font.weight: Font.DemiBold
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: page.m.links + " link(s) across "
                                  + Civic.collabPairs(page.sim, 0).length + " pair(s)"
                            color: Theme.mutedLight
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Pill {
                            text: page.m.consults + " consults"
                            fg: "#3F5C6B"
                            bg: Theme.blueLight
                            fontSize: 8
                        }

                        Pill {
                            text: page.m.joint + " paired jobs"
                            fg: "#3F5A26"
                            bg: Theme.sageLight
                            fontSize: 8
                        }

                        Pill {
                            text: page.m.handoffs + " handoffs"
                            fg: Theme.goldDeep
                            bg: Theme.goldLight
                            fontSize: 8
                        }

                        Pill {
                            text: page.m.reviews + " peer checks"
                            fg: Theme.clayDeep
                            bg: Theme.clayLight
                            fontSize: 8
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Repeater {
                        model: page.pairs

                        delegate: Text {
                            required property var modelData

                            Layout.fillWidth: true
                            text: page.pairLine(modelData)
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: page.pairs.length === 0
                        Layout.fillWidth: true
                        text: "No crew links yet. Agents start trading tasks once the board fills."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                    }
                }
            }

            Text {
                text: "CIVIC QUEUE"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
                font.letterSpacing: 1.6
                font.weight: Font.DemiBold
                Layout.topMargin: 4
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 10
                rowSpacing: 10

                Repeater {
                    model: Civic.DOMAINS

                    delegate: Rectangle {
                        required property var modelData
                        readonly property var stats: Civic.domainStats(page.sim, modelData.id)

                        Layout.fillWidth: true
                        implicitHeight: 168
                        radius: Theme.radiusMedium
                        color: Theme.white
                        border.width: 1
                        border.color: Theme.line

                        ColumnLayout {
                            id: laneBody
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 7

                                Rectangle {
                                    width: 7
                                    height: 7
                                    radius: 4
                                    color: modelData.color
                                }

                                Text {
                                    text: modelData.label
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: stats.open + " open · " + stats.active + " active · " + stats.closed + " closed"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.brief
                                color: Theme.mutedLight
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }

                            Repeater {
                                model: stats.top

                                delegate: RowLayout {
                                    required property var modelData
                                    readonly property var tone: page.statusTone(modelData.status)

                                    Layout.fillWidth: true
                                    spacing: 6

                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 3
                                        color: tone.fg
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        color: Theme.inkSoft
                                        font.family: Theme.uiFont
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: Civic.statusLabel(modelData.status)
                                        color: tone.fg
                                        font.family: Theme.uiFont
                                        font.pixelSize: 7
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            Text {
                                visible: stats.top.length === 0
                                Layout.fillWidth: true
                                text: "Clear — no open report."
                                color: Theme.mutedLight
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                Layout.fillWidth: true
                                text: "Agent " + Civic.personaById(modelData.guardian).agent
                                      + " · " + (modelData.cap - page.sim.budget.byDomain[modelData.id]) + " / " + modelData.cap + " DHN left"
                                color: Theme.mutedLight
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 372
                    radius: Theme.radiusLarge
                    color: Theme.white
                    border.width: 1
                    border.color: Theme.line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "PLAY-BY-PLAY"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                font.letterSpacing: 1.6
                                font.weight: Font.DemiBold
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "latest first"
                                color: Theme.mutedLight
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: feedColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: feedColumn
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: page.feed

                                    delegate: ColumnLayout {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        spacing: 1

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text {
                                                text: Civic.actorLabel(modelData.actor)
                                                color: page.toneInk(modelData.tone)
                                                font.family: Theme.uiFont
                                                font.pixelSize: 8
                                                font.weight: Font.DemiBold
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: "D" + modelData.day + " · " + Civic.PHASE_LABEL[modelData.phase]
                                                color: Theme.mutedLight
                                                font.family: Theme.uiFont
                                                font.pixelSize: 7
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.text
                                            color: Theme.inkSoft
                                            font.family: Theme.uiFont
                                            font.pixelSize: 9
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            visible: modelData.refs.length > 0
                                            Layout.fillWidth: true
                                            text: modelData.refs.join(" · ")
                                            color: Theme.mutedLight
                                            font.family: Theme.monoFont
                                            font.pixelSize: 7
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 372
                    implicitHeight: 372
                    radius: Theme.radiusLarge
                    color: Theme.paperWarm
                    border.width: 1
                    border.color: Theme.line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "NIGHT REFLECTIONS"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                font.letterSpacing: 1.6
                                font.weight: Font.DemiBold
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: page.reflections.length > 0 ? "day " + page.reflections[0].day : "—"
                                color: Theme.mutedLight
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }
                        }

                        Text {
                            visible: page.reflections.length === 0
                            Layout.fillWidth: true
                            text: "Reflections arrive after the night phase, from agents citing only the issues they touched."
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            wrapMode: Text.WordWrap
                        }

                        Flickable {
                            visible: page.reflections.length > 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: reflectionColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: reflectionColumn
                                width: parent.width
                                spacing: 10

                                Repeater {
                                    model: page.reflections

                                    delegate: ColumnLayout {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: modelData.agent + " · " + Civic.personaById(modelData.persona).name
                                            color: Theme.ink
                                            font.family: Theme.uiFont
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.takeaway
                                            color: Theme.inkSoft
                                            font.family: Theme.uiFont
                                            font.pixelSize: 9
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.unresolved
                                            color: Theme.muted
                                            font.family: Theme.uiFont
                                            font.pixelSize: 8
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.intention
                                            color: Theme.muted
                                            font.family: Theme.uiFont
                                            font.pixelSize: 8
                                            font.italic: true
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: "cites " + modelData.saw.join(" · ")
                                            color: Theme.mutedLight
                                            font.family: Theme.monoFont
                                            font.pixelSize: 7
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: limitBody.implicitHeight + 24
                radius: Theme.radiusMedium
                color: Theme.paperDeep
                border.width: 1
                border.color: Theme.line

                ColumnLayout {
                    id: limitBody
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        text: "WHAT THIS IS"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        font.letterSpacing: 1.4
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Civic.LIMITS
                        color: Theme.inkSoft
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Deterministic engine · seeds " + page.sim.seed + " · no model calls, no network, no persistence between sessions."
                        color: Theme.mutedLight
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
