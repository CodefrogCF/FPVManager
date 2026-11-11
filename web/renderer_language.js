(function (root, factory) {
    const api = factory();
    if (typeof module === 'object' && module.exports) module.exports = api;
    else root.FPVRendererLanguage = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    'use strict';

    const german = {
        'FPVManager – Loading 3D terrain...': 'FPVManager – 3D-Gelände wird geladen …',
        'Move': 'Bewegen',
        'Look': 'Blickrichtung',
        'Throttle / Yaw': 'Gas / Gieren',
        'Pitch / Roll': 'Nicken / Rollen',
        'Movement controls': 'Bewegungssteuerung',
        'Movement joystick. Drag to move; WASD and arrow keys also move.': 'Bewegungsstick. Ziehen oder WASD und Pfeiltasten verwenden.',
        'Look or attitude joystick': 'Stick für Blickrichtung oder Fluglage',
        'Climb': 'Steigen',
        'Descend': 'Sinken',
        'Flight simulation HUD': 'Anzeige für die Flugsimulation',
        'Automatic route playback': 'Automatische Routenwiedergabe',
        'Route playback progress': 'Fortschritt der Routenwiedergabe',
        'Restart': 'Neu starten',
        'Stop replay': 'Wiedergabe beenden',
        'Speed': 'Geschwindigkeit',
        'Route playback speed': 'Wiedergabegeschwindigkeit',
        'Simulated position, WGS84 latitude and longitude': 'Simulierte Position mit Breite und Länge in WGS84',
        'WGS84 · Latitude, longitude · Simulated position': 'WGS84 · Breite, Länge · Simulierte Position',
        'Record simulated flight': 'Simulierten Flug aufzeichnen',
        'Stop recording': 'Aufzeichnung beenden',
        'Stop flight recording': 'Flugaufzeichnung beenden',
        'Review flight recording': 'Flugaufzeichnung ansehen',
        'Exit flight': 'Flug beenden',
        'Pause recording': 'Aufzeichnung pausieren',
        'Resume recording': 'Aufzeichnung fortsetzen',
        'Review recording': 'Aufzeichnung ansehen',
        'FPV camera tilt in degrees': 'FPV-Kameraneigung in Grad',
        'FPV horizontal field of view in degrees': 'Horizontales FPV-Sichtfeld in Grad',
        'Flight HUD style': 'HUD-Stil im Flug',
        'Flight graphics profile': 'Grafikprofil im Flug',
        'Quality': 'Qualität',
        'Balanced': 'Ausgewogen',
        'Performance': 'Leistung',
        'Controller type': 'Controllertyp',
        'Zero-throttle stick position': 'Gas-Nullstellung',
        'Radio roll channel': 'Rollkanal der Fernsteuerung',
        'Radio pitch channel': 'Nickkanal der Fernsteuerung',
        'Radio throttle channel': 'Gaskanal der Fernsteuerung',
        'Radio yaw channel': 'Gierkanal der Fernsteuerung',
        'Reverse roll': 'Rollen umkehren',
        'Reverse pitch': 'Nicken umkehren',
        'Reverse throttle': 'Gas umkehren',
        'Reverse yaw': 'Gieren umkehren',
        'Channel {0}': 'Kanal {0}',
        'Flight telemetry': 'Flugtelemetrie',
        'SPEED': 'TEMPO',
        'Height above terrain at the current position': 'Höhe über Gelände an der aktuellen Position',
        'Height above the ground at the spawn point': 'Höhe über dem Gelände am Startpunkt',
        'Horizontal distance and direction to the spawn point': 'Horizontale Entfernung und Richtung zum Startpunkt',
        'Direction home': 'Richtung zum Startpunkt',
        'At the home point': 'Am Startpunkt',
        'Home direction {0}° from view heading': 'Startpunkt {0}° zur Blickrichtung',
        'Preparing flight…': 'Flug wird vorbereitet …',
        'Preparing flight… {0}%': 'Flug wird vorbereitet … {0} %',
        'Preparing route & terrain…': 'Route und Gelände werden vorbereitet …',
        'Resume': 'Fortsetzen',
        'Paused': 'Pausiert',
        'PAUSED': 'PAUSIERT',
        'Recorded': 'Aufgezeichnet',
        'REC': 'REC',
        '{0} · {1} samples · temporary': '{0} · {1} Messpunkte · temporär',
        'Terrain contact: movement stopped': 'Geländekontakt: Bewegung gestoppt',
        'Movement paused: terrain tiles not loaded': 'Bewegung pausiert: Geländekacheln fehlen',
        'Terrain unavailable; returned to globe view': 'Gelände nicht verfügbar. Zurück zur Karte.',
        'Tunnel continuation loading: movement paused': 'Tunnel wird nachgeladen. Bewegung pausiert.',
        'Simulated bridge or support surface contact: movement stopped': 'Kontakt mit Brücke oder Pfeiler: Bewegung gestoppt',
        'Approximate rendered 3D surface contact: movement stopped (not surveyed)': 'Kontakt mit angenäherter 3D-Oberfläche: Bewegung gestoppt',
        'Simulated tunnel surface contact: movement stopped': 'Kontakt mit Tunneloberfläche: Bewegung gestoppt',
        'Simulated infrastructure model contact; replay paused': 'Kontakt mit simuliertem Bauwerk. Wiedergabe pausiert.',
        'SIMULATION ONLY – tunnel dimensions are not surveyed': 'NUR SIMULATION – Tunnelmaße sind nicht vermessen',
        'Paused: tap the view to resume': 'Pausiert. Zum Fortsetzen auf die Ansicht tippen.',
        'Supported latitude limit reached': 'Grenze des unterstützten Breitengrads erreicht',
        'Unable to start simulated flight': 'Flugsimulation konnte nicht gestartet werden',
        'Renderer unavailable; returned to globe view': 'Darstellung nicht verfügbar. Zurück zur Karte.',
        'Ground: {0} m WGS84 | Eye: ≈ 2 m AGL | Look: {1}°': 'Gelände: {0} m WGS84 | Augenhöhe: ≈ 2 m AGL | Blick: {1}°',
        'Recent interruptions: {0}': 'Letzte Unterbrechungen: {0}',
        'Throttle': 'Gas',
        'FPVManager | 3D terrain loaded': 'FPVManager | 3D-Gelände geladen',
        'Connecting to 3D terrain | Flat map shown': 'Verbindung zum 3D-Gelände | Flache Karte',
        '3D terrain unavailable | Flat map shown — terrain heights disabled': '3D-Gelände nicht verfügbar | Flache Karte ohne Geländehöhen',
        'Controller ready': 'Controller bereit',
        'Controller disconnected': 'Controller getrennt',
        'Lower throttle fully and centre the other sticks to enable': 'Gas ganz zurücknehmen und die übrigen Sticks zentrieren',
        'Centre controller sticks to enable': 'Controller-Sticks zum Aktivieren zentrieren',
        'Lat: {0} | Lon: {1} | Height: {2} m (WGS84 ellipsoid, rendered terrain)': 'Breite: {0} | Länge: {1} | Höhe: {2} m (WGS84-Ellipsoid, dargestelltes Gelände)',
        'Lat: {0} | Lon: {1} | Flat map — terrain height unavailable': 'Breite: {0} | Länge: {1} | Flache Karte ohne Geländehöhe',
        'LOS: obstruction': 'LOS: blockiert',
        'LOS: sampled': 'LOS: Stichprobe',
        'Unknown / awaiting a terrain profile': 'Geländeprofil ausstehend',
        'Periodic geometric preview, not measured radio quality. Open details for sampling time and coverage.': 'Geometrische Vorschau ohne Messung der Funkqualität. Abfragezeit und Abdeckung stehen in den Details.',
    };
    const english = {
        'Nach Norden ausrichten': 'Orient north',
        'Standort verfolgen': 'Follow location',
        'Flugeinstellungen': 'Flight settings',
        'Kamera & Anzeige': 'Camera & display',
        'Kamera einstellen': 'Adjust camera',
        'Neigung': 'Tilt',
        'Sichtfeld': 'Field of view',
        'Koordinaten': 'Coordinates',
        'Touch-Steuerung': 'Touch controls',
        'Grafik & Licht': 'Graphics & lighting',
        'Grafik': 'Graphics',
        'Kompatibilität': 'Compatibility',
        'Zeit': 'Time',
        'Wie Karte': 'As on map',
        'Jetzt': 'Now',
        'Datum und Uhrzeit': 'Date and time',
        'Lokale Zeit': 'Local time',
        'Typ': 'Type',
        'USB-Funke / Tango 2': 'USB radio / Tango 2',
        'Nullgas': 'Zero throttle',
        'Stick unten': 'Stick at bottom',
        'Stick mittig': 'Stick centred',
        'Vor dem Flug Kanäle und Richtungen prüfen.': 'Check channels and directions before flying.',
        'Angle/Acro: Mit Nullgas und zentrierten Sticks verbinden.': 'Angle/Acro: Connect at zero throttle with the other sticks centred.',
        'Keine Winddaten geladen': 'No wind data loaded',
        'Aktueller Modellwind': 'Current modelled wind',
        'Windprognose': 'Wind forecast',
        'abgelaufen': 'expired',
        'Pfeile folgen der Strömung. Wind in m/s: grün <3, gelb 3–7, orange 7–12, rot ≥12. Open-Meteo, keine lokale Messung.': 'Arrows follow the flow. Wind in m/s: green <3, yellow 3–7, orange 7–12, red ≥12. Model data from Open-Meteo.',
        'Wind berücksichtigen': 'Apply wind',
        '3D-Pfeile': '3D arrows',
        'Quelle und Prognose wählen': 'Select source and forecast',
        'Funkvorschau': 'Radio preview',
        'Live-Vorschau': 'Live preview',
        'Aus': 'Off',
        'Sender & Details': 'Transmitter & details',
        'Flug zurücksetzen': 'Reset flight',
        'Nächste Modellschicht konstant fortgesetzt': 'Extended from the nearest model layer',
        'Interpolierter Modellwind': 'Interpolated model wind',
        'Wind fehlt, ist abgelaufen oder liegt außerhalb des geladenen Ausschnitts. Physik ohne Wind.': 'Wind data is missing, expired or outside the loaded area. Flight physics uses no wind.',
    };
    const hasMessage = message => Object.hasOwn(german, message) || Object.hasOwn(english, message);

    function create(document) {
        let language;
        const bindings = [];
        const listeners = new Set();
        function translate(source, ...values) {
            const catalog = language === 'de' ? german : language === 'en' ? english : null;
            const template = catalog && Object.hasOwn(catalog, source) ? catalog[source] : source;
            return values.length ? template.replace(/\{(\d+)\}/g, (match, index) =>
                index < values.length ? String(values[index]) : match) : template;
        }
        // Capture the app's static markup before any provider or user data is
        // attached. Dynamic labels are refreshed by their owning controls.
        const walker = document.createTreeWalker(document.body, 4);
        while (walker.nextNode()) {
            const node = walker.currentNode;
            const original = node.nodeValue;
            const key = original.trim();
            if (hasMessage(key)) {
                bindings.push(() => {
                    if (node.isConnected) node.nodeValue = original.replace(key, () => translate(key));
                });
            }
        }
        for (const element of document.querySelectorAll('[title], [aria-label]')) {
            for (const attribute of ['title', 'aria-label']) {
                const source = element.getAttribute(attribute);
                if (!source || !hasMessage(source)) continue;
                let previous = source;
                bindings.push(() => {
                    if (element.getAttribute(attribute) !== previous) return;
                    previous = translate(source);
                    element.setAttribute(attribute, previous);
                });
            }
        }
        function setLanguage(next) {
            if (next !== 'de' && next !== 'en') throw new Error('Unsupported app language');
            if (next === language) return;
            language = next;
            document.documentElement.lang = language;
            for (const bind of bindings) bind();
            for (const [property, message] of Object.entries({
                '--fpv-move-label': 'Move',
                '--fpv-look-label': 'Look',
                '--fpv-throttle-label': 'Throttle / Yaw',
                '--fpv-attitude-label': 'Pitch / Roll',
            })) document.body.style.setProperty(property, JSON.stringify(translate(message)));
            for (const listener of listeners) listener();
        }
        return {
            translate,
            setLanguage,
            get locale() { return language; },
            onChange(listener) {
                listeners.add(listener);
                return () => listeners.delete(listener);
            },
        };
    }

    return {create};
});
