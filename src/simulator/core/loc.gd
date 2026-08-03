extends Node
## Loc — trilingual (English / Español / Nederlands) string table.
##
## Per 01_MASTER_PROMPT_V2.md: English professional terminology first, literal
## Spanish beside it, Dutch preserved where the Dutch term is the one a learner
## will actually meet on a Dutch site (bovenloopkraan, loopkat, stempels,
## seingever, buitendienststelling). Modes: EN_ES (default), EN, ES, NL.
## Cycle with L. Entries are [en, es, nl]; nl may be "" to fall back to en.
##
## `pick()` is the sibling of `t()` for strings that live in DATA rather than
## in this table — machine names, scenario briefings, weather names. Catalogue
## entries carry {en, es, nl} dictionaries and pick() applies the same
## language rule to them, so data-driven text localises exactly like UI text.

## Loc deliberately depends on NOTHING else. It used to write the chosen
## language straight into GameState, which coupled the string table to the save
## system and made every module that merely wanted a translated word fail to
## compile without the whole autoload graph present. Now it just announces the
## change and GameState listens.
signal language_changed(lang: int)

enum { LANG_EN_ES, LANG_EN, LANG_ES, LANG_NL }

## STATIC on purpose. Data modules (the machine, environment and weather
## catalogues, the scenario database) hold localisable {en, es, nl} fields and
## need to render them. If they had to reach the autoload INSTANCE they could
## not be compiled or unit-tested without the whole autoload graph present —
## which is exactly what used to break tests/module_tests.gd. As a static
## table, `preload("res://core/loc.gd").pick(field)` works anywhere, and the
## autoload instance exists only to own the change signal.
static var lang := LANG_EN_ES

const S := {
	# --- shell / menu ------------------------------------------------------
	"app_title": ["GELDERLAND OPERATOR ACADEMY", "GELDERLAND OPERATOR ACADEMY", "GELDERLAND OPERATOR ACADEMY"],
	"app_sub": ["Crane & lifting simulator — training aid, not a certificate",
		"Simulador de grúas y elevación — ayuda formativa, no es un certificado",
		"Kraan- en hijssimulator — oefenhulp, geen certificaat"],
	"menu_training": ["Training programme", "Programa de formación", "Opleidingsprogramma"],
	"menu_training_sub": ["Structured lessons, in order, from pendant crane to mobile crane",
		"Lecciones estructuradas y en orden, del puente grúa a la grúa móvil",
		"Gestructureerde lessen op volgorde"],
	"menu_scenarios": ["Scenarios", "Escenarios", "Scenario's"],
	"menu_scenarios_sub": ["Pick any job in any site and weather",
		"Elige cualquier trabajo, emplazamiento y clima",
		"Kies elke klus, locatie en weer"],
	"menu_free": ["Free practice", "Práctica libre", "Vrij oefenen"],
	"menu_free_sub": ["No objective, no score — just you and the machine",
		"Sin objetivo ni puntuación: tú y la máquina",
		"Geen doel, geen score — alleen jij en de machine"],
	"menu_controls": ["Controls", "Controles", "Bediening"],
	"menu_settings": ["Settings", "Ajustes", "Instellingen"],
	"menu_quit": ["Quit", "Salir", "Afsluiten"],
	"menu_back": ["Back", "Volver", "Terug"],
	"menu_start": ["START", "EMPEZAR", "START"],
	"menu_continue": ["Continue", "Continuar", "Doorgaan"],
	"menu_resume": ["Resume", "Reanudar", "Hervatten"],
	"menu_restart": ["Restart", "Reiniciar", "Opnieuw"],
	"menu_to_menu": ["Main menu", "Menú principal", "Hoofdmenu"],
	"menu_progress": ["Progress", "Progreso", "Voortgang"],
	"menu_machine": ["Machine", "Máquina", "Machine"],
	"menu_site": ["Site", "Emplazamiento", "Locatie"],
	"menu_weather": ["Weather", "Clima", "Weer"],
	"menu_difficulty": ["Mode", "Modo", "Modus"],
	"menu_completed": ["completed", "completados", "voltooid"],
	"menu_locked_env": ["Not available on this site", "No disponible en este emplazamiento", "Niet beschikbaar op deze locatie"],

	# --- legal / disclaimer ------------------------------------------------
	"disclaimer": [
		"TRAINING AID ONLY. Simulator performance is not a legal certification and does not substitute for TCVT, VCA, a driving licence or any accredited course. Load charts shown are plausible training envelopes, NOT manufacturer data for any real machine.",
		"SOLO AYUDA FORMATIVA. El rendimiento en el simulador no es una certificación legal ni sustituye a TCVT, VCA, un permiso de conducir ni ningún curso acreditado. Las tablas de cargas mostradas son envolventes de práctica plausibles, NO datos de fabricante de ninguna máquina real.",
		"ALLEEN OEFENHULP. Prestaties in de simulator zijn geen wettelijke certificering en vervangen TCVT, VCA of een rijbewijs niet. De getoonde laadtabellen zijn oefenwaarden, GEEN fabrieksgegevens."],
	"chart_disclaimer": ["Training envelope — not manufacturer data",
		"Envolvente de práctica — no son datos del fabricante",
		"Oefenwaarden — geen fabrieksgegevens"],

	# --- controls card ------------------------------------------------------
	"ctrl_hdr_operate": ["OPERATING THE MACHINE", "OPERANDO LA MÁQUINA", "DE MACHINE BEDIENEN"],
	"ctrl_hdr_foot": ["ON FOOT", "A PIE", "TE VOET"],
	"ctrl_hdr_any": ["ANY TIME", "EN CUALQUIER MOMENTO", "ALTIJD"],
	"ctrl_universal": ["Same on every machine: R/F hoist · SHIFT creep · SPACE all-stop",
		"Igual en todas las máquinas: R/F izar · SHIFT lento · ESPACIO parada total",
		"Op elke machine gelijk: R/F hijsen · SHIFT kruipen · SPATIE alles stop"],
	"controls_walk": ["WASD walk · SHIFT run · SPACE jump · Mouse look · E take the controls",
		"WASD caminar · SHIFT correr · ESPACIO saltar · Ratón mirar · E coger los mandos",
		"WASD lopen · SHIFT rennen · SPATIE springen · Muis kijken · E bediening pakken"],
	"fine_short": ["creep", "lento", "kruipen"],
	"stop_short": ["ALL STOP", "PARADA", "STOP"],
	"exit_short": ["leave controls", "soltar mandos", "bediening loslaten"],
	"help_title": ["CONTROLS (F1 to close)", "CONTROLES (F1 para cerrar)", "BEDIENING (F1 sluit)"],

	# --- machine state ------------------------------------------------------
	"power": ["Power", "Corriente", "Voeding"],
	"on": ["ON", "ENCENDIDO", "AAN"],
	"off": ["OFF", "APAGADO", "UIT"],
	"inspection": ["Pre-use check", "Comprobación previa", "Controle vooraf"],
	"insp_hint": ["Complete the pre-use checks before the machine will run",
		"Completa las comprobaciones previas para que la máquina arranque",
		"Voltooi de controles voordat de machine start"],
	"insp_1": ["Brakes & emergency stop", "Frenos y parada de emergencia", "Remmen & noodstop"],
	"insp_2": ["Limit switches", "Finales de carrera", "Eindschakelaars"],
	"insp_3": ["Hook, latch & rope", "Gancho, pestillo y cable", "Haak, klep & kabel"],
	"insp_4": ["Ground & set-up area", "Terreno y zona de estacionamiento", "Ondergrond & opstelplaats"],
	"estop": ["EMERGENCY STOP ENGAGED", "PARADA DE EMERGENCIA ACTIVADA", "NOODSTOP ACTIEF"],
	"outriggers": ["Outriggers", "Estabilizadores", "Stempels"],
	"outriggers_out": ["DEPLOYED", "DESPLEGADOS", "UITGESTEMPELD"],
	"outriggers_in": ["STOWED", "RECOGIDOS", "INGETROKKEN"],
	"outriggers_hint": ["Press O to deploy the outriggers — the machine will not slew or telescope until they are down",
		"Pulsa O para desplegar los estabilizadores — la máquina no girará ni telescopará hasta que estén abajo",
		"Druk op O om te stempelen — zwenken en telescoperen kan pas als de stempels staan"],

	# --- readouts -----------------------------------------------------------
	"cable": ["Rope out", "Cable soltado", "Kabel uit"],
	"mass": ["Load", "Carga", "Last"],
	"gross": ["Gross load", "Carga bruta", "Brutolast"],
	"swing": ["Swing", "Balanceo", "Slingering"],
	"tension": ["Rope tension", "Tensión del cable", "Kabelspanning"],
	"wind": ["Wind", "Viento", "Wind"],
	"radius": ["Radius", "Radio", "Vlucht"],
	"capacity": ["Rated at radius", "Nominal a este radio", "Toegestaan bij vlucht"],
	"utilisation": ["Load moment", "Momento de carga", "Lastmoment"],
	"hook_height": ["Hook height", "Altura del gancho", "Haakhoogte"],
	"boom_angle": ["Boom angle", "Ángulo de pluma", "Giekhoek"],
	"boom_length": ["Boom length", "Longitud de pluma", "Gieklengte"],
	"slew_angle": ["Slew", "Giro", "Zwenkhoek"],
	"time": ["Time", "Tiempo", "Tijd"],
	"stability": ["Stability", "Estabilidad", "Stabiliteit"],
	"visibility": ["Visibility", "Visibilidad", "Zicht"],
	"wind_limit": ["Wind limit", "Límite de viento", "Windlimiet"],

	# --- LMI / stability alarms ---------------------------------------------
	"lmi_safe": ["Within chart", "Dentro de tabla", "Binnen tabel"],
	"lmi_notice": ["75% of rated", "75% del nominal", "75% van toegestaan"],
	"lmi_warning": ["PRE-ALARM 90%", "PREALARMA 90%", "VOORALARM 90%"],
	"lmi_overload": ["OVERLOAD — REDUCE RADIUS OR LOAD", "SOBRECARGA — REDUCE RADIO O CARGA", "OVERBELASTING — VLUCHT OF LAST VERMINDEREN"],
	"lmi_out_of_chart": ["OFF THE CHART — NO RATING AT THIS RADIUS", "FUERA DE TABLA — SIN VALOR NOMINAL A ESTE RADIO", "BUITEN DE TABEL — GEEN WAARDE BIJ DEZE VLUCHT"],
	"stab_stable": ["Stable", "Estable", "Stabiel"],
	"stab_caution": ["Stability margin low", "Margen de estabilidad bajo", "Kleine stabiliteitsmarge"],
	"stab_critical": ["CRITICAL — machine close to tipping", "CRÍTICO — máquina al borde del vuelco", "KRITIEK — machine bijna kantelend"],
	"stab_tipping": ["TIPPING", "VUELCO", "KANTELT"],
	"over_wind": ["WIND OVER LIMIT — STOP LIFTING", "VIENTO SOBRE EL LÍMITE — DETÉN LA MANIOBRA", "WIND BOVEN LIMIET — STOP HET HIJSEN"],

	# --- access / operating -------------------------------------------------
	"prompt_approach": ["Walk to the marked control position and press E",
		"Camina hasta el puesto de mando marcado y pulsa E",
		"Loop naar de gemarkeerde bedieningsplek en druk op E"],
	"prompt_in_zone": ["Press E to take the controls", "Pulsa E para coger los mandos",
		"Druk op E om de bediening over te nemen"],
	"prompt_exit": ["Press X to leave the controls", "Pulsa X para soltar los mandos",
		"Druk op X om de bediening los te laten"],
	"access_label": ["CONTROL POSITION", "PUESTO DE MANDO", "BEDIENINGSPLEK"],
	"access_pendant": ["PENDANT CONTROL", "MANDO COLGANTE", "HANGBEDIENING"],
	"access_cabin": ["CAB — PRESS E TO CLIMB IN", "CABINA — PULSA E PARA SUBIR", "CABINE — DRUK E OM IN TE STAPPEN"],
	"access_ground": ["GROUND CONTROL STAND", "PUESTO DE MANDO EN SUELO", "GRONDBEDIENING"],

	# --- objectives / scoring ------------------------------------------------
	"objective": ["Objective", "Objetivo", "Doel"],
	"briefing": ["Briefing", "Instrucciones", "Briefing"],
	"zone_a": ["PICK UP HERE", "RECOGER AQUÍ", "HIER OPPAKKEN"],
	"zone_b": ["SET DOWN HERE", "DEPOSITAR AQUÍ", "HIER NEERZETTEN"],
	"obj_not_started": ["Lower the hook onto the load in the pick-up zone",
		"Baja el gancho sobre la carga en la zona de recogida",
		"Laat de haak zakken op de last in de ophaalzone"],
	"obj_carrying": ["Carry the load to the set-down zone — keep the swing under control",
		"Lleva la carga a la zona de entrega — controla el balanceo",
		"Breng de last naar de afzetzone — houd de slingering onder controle"],
	"obj_delivered": ["Delivered", "Entregado", "Afgeleverd"],
	"obj_stopped": ["Correctly stopped work", "Trabajo detenido correctamente", "Werk correct gestaakt"],
	"score_time": ["Time", "Tiempo", "Tijd"],
	"score_swing": ["Max swing", "Balanceo máx.", "Max slingering"],
	"score_hits": ["Collisions", "Colisiones", "Botsingen"],
	"score_violations": ["Safety violations", "Infracciones de seguridad", "Veiligheidsovertredingen"],
	"score_near_miss": ["Near misses", "Casi-accidentes", "Bijna-ongevallen"],
	"score_overload": ["Overload seconds", "Segundos en sobrecarga", "Seconden overbelast"],
	"score_precision": ["Placement accuracy", "Precisión de colocación", "Plaatsingsnauwkeurigheid"],
	"score_points": ["Score", "Puntuación", "Score"],
	"result_pass": ["PASS", "APTO", "GESLAAGD"],
	"result_fail": ["NOT YET", "AÚN NO", "NOG NIET"],
	"result_title": ["Lift complete", "Maniobra completada", "Hijsklus voltooid"],
	"result_best": ["Personal best", "Mejor marca personal", "Persoonlijk record"],
	"result_why": ["What decided it", "Qué lo ha decidido", "Wat de doorslag gaf"],
	"result_next": ["Next scenario", "Siguiente escenario", "Volgend scenario"],
	"result_retry": ["Try again", "Reintentar", "Opnieuw proberen"],

	# --- safety messages ------------------------------------------------------
	"danger_load": ["LOAD CONTACT — NEVER STAND UNDER A SUSPENDED LOAD",
		"CONTACTO CON LA CARGA — NUNCA TE SITÚES BAJO UNA CARGA SUSPENDIDA",
		"LASTCONTACT — NOOIT ONDER EEN HANGENDE LAST STAAN"],
	"caution_near": ["CAUTION — you are inside the load's swing radius",
		"PRECAUCIÓN — estás dentro del radio de balanceo de la carga",
		"LET OP — je staat binnen de zwenkstraal van de last"],
	"impact_floor": ["Load struck the ground", "La carga golpeó el suelo", "Last raakte de grond"],
	"impact_column": ["Load struck a column", "La carga golpeó una columna", "Last raakte een kolom"],
	"impact_obstacle": ["Load struck an obstacle", "La carga golpeó un obstáculo", "Last raakte een obstakel"],
	"violation_public": ["Load carried over a public area", "Carga transportada sobre zona pública", "Last over openbaar gebied"],
	"violation_track": ["Load fouled the adjacent track", "La carga invadió la vía contigua", "Last kwam boven het naastgelegen spoor"],
	"violation_line": ["Too close to the overhead line", "Demasiado cerca de la catenaria", "Te dicht bij de bovenleiding"],
	"violation_water": ["Load carried over open water", "Carga transportada sobre el agua", "Last boven open water"],
	"fault": ["PHYSICS FAULT — simulation halted, press BACKSPACE",
		"FALLO DE FÍSICA — simulación detenida, pulsa RETROCESO",
		"FYSICAFOUT — simulatie gestopt, druk BACKSPACE"],

	# --- signaller ------------------------------------------------------------
	"signaller": ["Signaller", "Señalista", "Seingever"],
	"sig_hint": ["Press B to ask the signaller — they can see what you cannot",
		"Pulsa B para preguntar al señalista — ve lo que tú no ves",
		"Druk op B om de seingever te vragen — die ziet wat jij niet ziet"],
	"sig_hoist_up": ["Signal: HOIST UP", "Señal: IZAR", "Sein: HIJSEN"],
	"sig_hoist_down": ["Signal: LOWER", "Señal: BAJAR", "Sein: VIEREN"],
	"sig_slew_left": ["Signal: SLEW LEFT", "Señal: GIRAR IZQUIERDA", "Sein: ZWENKEN LINKS"],
	"sig_slew_right": ["Signal: SLEW RIGHT", "Señal: GIRAR DERECHA", "Sein: ZWENKEN RECHTS"],
	"sig_out": ["Signal: BOOM OUT", "Señal: SACAR PLUMA", "Sein: GIEK UIT"],
	"sig_in": ["Signal: BOOM IN", "Señal: METER PLUMA", "Sein: GIEK IN"],
	"sig_stop": ["Signal: STOP", "Señal: ALTO", "Sein: STOP"],
	"sig_ok": ["Signal: CLEAR TO PROCEED", "Señal: VÍA LIBRE", "Sein: VRIJ OM VERDER TE GAAN"],

	# --- load chart screen -----------------------------------------------------
	"chart_title": ["LOAD CHART & LIFT PLAN", "TABLA DE CARGAS Y PLAN DE IZADO", "LAADTABEL & HIJSPLAN"],
	"chart_radius": ["Radius (m)", "Radio (m)", "Vlucht (m)"],
	"chart_capacity": ["Rated (kg)", "Nominal (kg)", "Toegestaan (kg)"],
	"chart_current": ["you are here", "estás aquí", "je bent hier"],
	"chart_max_radius": ["Max radius for this load", "Radio máximo para esta carga", "Max vlucht voor deze last"],
	"rig_plan": ["Rigging", "Eslingado", "Aanslaan"],
	"rig_legs": ["Sling legs", "Ramales", "Strengen"],
	"rig_angle": ["Angle to horizontal", "Ángulo con la horizontal", "Hoek met horizontaal"],
	"rig_leg_tension": ["Tension per leg", "Tensión por ramal", "Spanning per streng"],
	"rig_required_wll": ["WLL needed per leg", "CMU necesaria por ramal", "WLL nodig per streng"],
	"rig_angle_bad": ["Sling angle below 30° — do not rig like this",
		"Ángulo de eslinga por debajo de 30° — no eslingues así",
		"Stroppenhoek onder 30° — zo niet aanslaan"],

	# --- camera ---------------------------------------------------------------
	"cam_walk": ["First person", "Primera persona", "Eerste persoon"],
	"cam_orbit": ["Orbit view", "Vista orbital", "Rondzicht"],
	"cam_hook": ["Hook camera", "Cámara de gancho", "Haakcamera"],
	"cam_topdown": ["Top-down", "Cenital", "Bovenaanzicht"],
	"cam_cabin": ["Operator's eye", "Vista del operador", "Bedienerszicht"],
	"cam_boom": ["Boom tip", "Punta de pluma", "Giektop"],

	# --- tutorial steps --------------------------------------------------------
	"tut_welcome": ["Walk with WASD. The control position is marked on the ground — go there.",
		"Camina con WASD. El puesto de mando está marcado en el suelo: ve hasta allí.",
		"Loop met WASD. De bedieningsplek is op de grond gemarkeerd."],
	"tut_take": ["Press E to take the controls.", "Pulsa E para coger los mandos.",
		"Druk op E om de bediening over te nemen."],
	"tut_outriggers": ["Press O and hold. The machine stays locked until the outriggers are fully down.",
		"Pulsa O y mantén. La máquina sigue bloqueada hasta que los estabilizadores estén abajo del todo.",
		"Houd O ingedrukt tot de stempels volledig staan."],
	"tut_inspect": ["Run the pre-use checks with the number keys. The crane will not power up until they are done.",
		"Haz las comprobaciones previas con las teclas numéricas. La grúa no se energiza hasta terminarlas.",
		"Doe de controles met de cijfertoetsen. De kraan start pas daarna."],
	"tut_hoist": ["R raises, F lowers. Lower the hook until it is just over the load.",
		"R iza, F baja. Baja el gancho hasta justo encima de la carga.",
		"R hijst, F viert. Laat de haak zakken tot net boven de last."],
	"tut_travel": ["Now move the machine. Short taps, then let it settle — a load that is already swinging is hard to stop.",
		"Ahora mueve la máquina. Toques cortos y deja que se asiente: una carga que ya balancea es difícil de parar.",
		"Beweeg nu de machine. Korte tikken, dan laten uitzwingen."],
	"tut_creep": ["Hold SHIFT for creep speed when you are close to the target.",
		"Mantén SHIFT para velocidad lenta cuando estés cerca del objetivo.",
		"Houd SHIFT vast voor kruipsnelheid dicht bij het doel."],
	"tut_chart": ["Press H to read the load chart. Know the rated capacity at your radius BEFORE you lift.",
		"Pulsa H para leer la tabla de cargas. Conoce la capacidad nominal a tu radio ANTES de izar.",
		"Druk op H voor de laadtabel. Ken de waarde bij jouw vlucht vóór het hijsen."],
	"tut_stop": ["SPACE is ALL STOP. Use it now so your hand knows where it is.",
		"ESPACIO es PARADA TOTAL. Úsala ahora para que tu mano sepa dónde está.",
		"SPATIE is ALLES STOP. Gebruik hem nu even."],
	"tut_deliver": ["Set the load down gently inside the marked zone and let it rest.",
		"Deposita la carga suavemente dentro de la zona marcada y déjala asentarse.",
		"Zet de last rustig neer binnen de gemarkeerde zone."],
	"tut_done": ["Lift complete. Press X to leave the controls.",
		"Maniobra completada. Pulsa X para soltar los mandos.",
		"Klus klaar. Druk op X om de bediening los te laten."],

	# --- settings --------------------------------------------------------------
	"set_language": ["Language", "Idioma", "Taal"],
	"set_sensitivity": ["Mouse sensitivity", "Sensibilidad del ratón", "Muisgevoeligheid"],
	"set_invert": ["Invert vertical look", "Invertir mirada vertical", "Verticaal omkeren"],
	"set_volume": ["Volume", "Volumen", "Volume"],
	"set_keys": ["Show key overlay", "Mostrar teclas en pantalla", "Toetsen tonen"],
	"set_path": ["Show guidance arrows", "Mostrar flechas de guía", "Pijlen tonen"],
	"set_reset": ["Reset all progress", "Borrar todo el progreso", "Voortgang wissen"],
	"set_reset_confirm": ["Press again to confirm", "Pulsa otra vez para confirmar", "Nogmaals drukken om te bevestigen"],
	"paused": ["PAUSED", "EN PAUSA", "GEPAUZEERD"],
}


static func t(key: String) -> String:
	var e: Array = S.get(key, [])
	if e.is_empty():
		return key
	match lang:
		LANG_EN:
			return e[0]
		LANG_ES:
			return e[1] if e[1] != "" else e[0]
		LANG_NL:
			return e[2] if e.size() > 2 and e[2] != "" else e[0]
		_:
			if e[0] == e[1]:
				return e[0]
			if "\n" in e[0]:
				return e[0] + "\n" + e[1]
			return "%s / %s" % [e[0], e[1]]


## Same language rule as t(), applied to a {en, es, nl} dictionary that lives
## in data (catalogue entries, scenario JSON) rather than in the table above.
static func pick(field: Dictionary) -> String:
	if field.is_empty():
		return ""
	var en := String(field.get("en", ""))
	var es := String(field.get("es", en))
	var nl := String(field.get("nl", en))
	match lang:
		LANG_EN: return en
		LANG_ES: return es if es != "" else en
		LANG_NL: return nl if nl != "" else en
		_:
			if en == es or es == "":
				return en
			if "\n" in en:
				return en + "\n" + es
			return "%s / %s" % [en, es]


func cycle() -> void:
	set_lang((lang + 1) % 4)


func set_lang(new_lang: int) -> void:
	lang = clampi(new_lang, 0, 3)
	language_changed.emit(lang)


static func lang_name() -> String:
	match lang:
		LANG_EN: return "EN"
		LANG_ES: return "ES"
		LANG_NL: return "NL"
		_: return "EN/ES"
