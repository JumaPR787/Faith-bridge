import 'package:material_ui/material_ui.dart';

/// Textos de la interfaz en español (es) e inglés (en).
/// Una prueba automática verifica que toda clave usada exista en ambos idiomas.
const Map<String, List<String>> kStrings = {
  // [español, inglés]
  'app_name': ['FaithBridge', 'FaithBridge'],
  'continue': ['Continuar', 'Continue'],
  'cancel': ['Cancelar', 'Cancel'],
  'close': ['Cerrar', 'Close'],
  'retry': ['Reintentar', 'Retry'],
  'delete': ['Eliminar', 'Delete'],
  'confirm': ['Confirmar', 'Confirm'],
  'error_generic': ['Algo salió mal. Inténtalo de nuevo.', 'Something went wrong. Please try again.'],
  'error_network': ['Sin conexión con el servidor. Esta función requiere internet.', 'Cannot reach the server. This feature requires internet.'],
  'simulated_badge': ['DATOS SIMULADOS (desarrollo)', 'SIMULATED DATA (development)'],

  // Bienvenida
  'welcome_title': ['Comprende cada predicación', 'Understand every sermon'],
  'welcome_body': [
    'FaithBridge muestra por escrito lo que se dice en el servicio y, si quieres, su traducción entre inglés y español.',
    'FaithBridge shows in writing what is said during the service and, if you want, its translation between English and Spanish.'
  ],
  'welcome_limits': [
    'La transcripción y la traducción son automáticas: pueden tener errores y aparecen con unos segundos de retraso. Requiere conexión a internet.',
    'Transcription and translation are automatic: they may contain mistakes and appear a few seconds late. An internet connection is required.'
  ],
  'choose_ui_language': ['Idioma de la aplicación', 'App language'],

  // Privacidad
  'privacy_title': ['Tu privacidad', 'Your privacy'],
  'privacy_mic': [
    'El micrófono solo se activa cuando tocas «Iniciar». Verás un indicador mientras se usa.',
    'The microphone only turns on when you tap “Start”. You will see an indicator while it is in use.'
  ],
  'privacy_audio': [
    'El audio se envía de forma segura a nuestro servidor y a nuestro proveedor de reconocimiento de voz para convertirlo en texto. No guardamos el audio.',
    'Audio is sent securely to our server and to our speech-recognition provider to turn it into text. We do not store the audio.'
  ],
  'privacy_translation': [
    'Para traducir, el texto se envía a nuestro proveedor de traducción con IA.',
    'To translate, the text is sent to our AI translation provider.'
  ],
  'privacy_saving': [
    'Las transcripciones solo se guardan si activas «Guardar transcripción». Puedes borrarlas, junto con tu cuenta, cuando quieras.',
    'Transcripts are only saved if you turn on “Save transcript”. You can delete them, and your account, at any time.'
  ],
  'privacy_training': [
    'No usamos tu contenido para entrenar modelos de IA.',
    'We do not use your content to train AI models.'
  ],
  'privacy_consent_others': [
    'Graba o procesa solo audio que tengas permiso de captar. Respeta las normas de tu iglesia.',
    'Only capture audio you are allowed to capture. Respect your church’s rules.'
  ],
  'privacy_read_policy': ['Leer la política de privacidad', 'Read the privacy policy'],
  'privacy_accept': ['Entiendo y acepto', 'I understand and agree'],

  // Inicio de sesión
  'signin_title': ['Inicia sesión', 'Sign in'],
  'signin_body': [
    'Te enviaremos un código a tu correo. Tu cuenta permite usar tu suscripción en varios dispositivos.',
    'We will email you a code. Your account lets you use your subscription on several devices.'
  ],
  'email': ['Correo electrónico', 'Email'],
  'send_code': ['Enviar código', 'Send code'],
  'code': ['Código', 'Code'],
  'verify': ['Verificar', 'Verify'],
  'signin_invalid_email': ['Escribe un correo válido.', 'Enter a valid email.'],
  'signin_invalid_code': ['Código incorrecto o vencido.', 'Incorrect or expired code.'],

  // Inicio
  'home_title': ['Inicio', 'Home'],
  'mode_personal': ['Modo personal', 'Personal mode'],
  'mode_personal_desc': ['Usa el micrófono de tu teléfono.', 'Use your phone’s microphone.'],
  'mode_church': ['Modo iglesia', 'Church mode'],
  'mode_church_desc': ['Próximamente: recibe el texto del sistema de sonido de tu iglesia.', 'Coming soon: receive text from your church’s sound system.'],
  'coming_soon': ['Próximamente', 'Coming soon'],
  'text_translate': ['Traducir texto', 'Translate text'],
  'text_translate_desc': ['Pega un texto o traduce una transcripción guardada.', 'Paste text or translate a saved transcript.'],
  'history': ['Historial', 'History'],
  'plans': ['Planes', 'Plans'],
  'settings': ['Ajustes', 'Settings'],
  'help': ['Ayuda', 'Help'],
  'minutes_left': ['Minutos disponibles', 'Minutes available'],
  'renews_on': ['Se renueva el', 'Renews on'],
  'trial_ends_on': ['La prueba termina el', 'Trial ends on'],
  'no_plan': ['No tienes un plan activo.', 'You don’t have an active plan.'],
  'see_plans': ['Ver planes', 'See plans'],
  'service_paused': ['El servicio en vivo está pausado temporalmente. Tus transcripciones guardadas siguen disponibles.', 'Live service is temporarily paused. Your saved transcripts are still available.'],

  // Selección de idiomas
  'setup_title': ['Preparar sesión', 'Set up session'],
  'speaker_language': ['¿En qué idioma se predica?', 'What language is being spoken?'],
  'english': ['Inglés', 'English'],
  'spanish': ['Español', 'Spanish'],
  'what_to_show': ['¿Qué quieres ver?', 'What do you want to see?'],
  'show_original': ['Solo transcripción (idioma original)', 'Transcription only (original language)'],
  'show_translation': ['Solo traducción', 'Translation only'],
  'show_both': ['Original y traducción', 'Original and translation'],
  'translate_to': ['Traducir a', 'Translate to'],
  'save_transcript': ['Guardar transcripción', 'Save transcript'],
  'save_transcript_desc': ['Se guardará en tu historial hasta que la borres o venza el plazo de conservación.', 'It will be kept in your history until you delete it or the retention period ends.'],
  'ambient_notice': [
    'Consejo: acércate a un altavoz. El ruido, el eco, la música y la distancia afectan la calidad.',
    'Tip: sit near a speaker. Noise, echo, music and distance affect quality.'
  ],
  'start': ['Iniciar', 'Start'],

  // En vivo
  'live_title': ['Subtítulos en vivo', 'Live captions'],
  'mic_on': ['Micrófono activo', 'Microphone on'],
  'mic_paused': ['Micrófono en pausa', 'Microphone paused'],
  'pause': ['Pausar', 'Pause'],
  'resume': ['Reanudar', 'Resume'],
  'finish': ['Finalizar', 'Finish'],
  'finish_confirm': ['¿Finalizar la sesión?', 'End the session?'],
  'connecting': ['Conectando…', 'Connecting…'],
  'reconnecting': ['Reconectando… (el audio de este momento no se procesa)', 'Reconnecting… (audio during this time is not processed)'],
  'connected': ['Conectado', 'Connected'],
  'processing': ['Procesando', 'Processing'],
  'translating': ['Traduciendo…', 'Translating…'],
  'translation_unavailable': ['[traducción no disponible]', '[translation unavailable]'],
  'listening': ['Escuchando… El texto aparecerá en unos segundos.', 'Listening… Text will appear in a few seconds.'],
  'elapsed': ['Tiempo usado', 'Time used'],
  'remaining': ['Disponible', 'Available'],
  'autoscroll_paused': ['Desplazamiento pausado', 'Auto-scroll paused'],
  'jump_to_latest': ['Ir a lo más reciente', 'Jump to latest'],
  'quota_warning': ['Te quedan pocos minutos en este periodo.', 'You have only a few minutes left this period.'],
  'ended_quota': ['Se agotaron tus minutos de este periodo. No se hizo ningún cargo adicional.', 'You have used all your minutes for this period. No extra charge was made.'],
  'ended_max_duration': ['Se alcanzó la duración máxima de una sesión. Puedes iniciar otra.', 'Maximum session length reached. You can start another one.'],
  'ended_superseded': ['La sesión se abrió en otro dispositivo.', 'The session was opened on another device.'],
  'ended_stt': ['El servicio de reconocimiento de voz no está disponible ahora.', 'The speech-recognition service is unavailable right now.'],
  'ended_ok': ['Sesión finalizada.', 'Session ended.'],
  'saved_in_history': ['Guardada en tu historial.', 'Saved to your history.'],
  'paused_background': ['La sesión se pausó porque la app pasó a segundo plano. Toca «Reanudar» para continuar.', 'The session was paused because the app went to the background. Tap “Resume” to continue.'],
  'paused_interruption': ['La sesión se pausó por una llamada u otra app de audio. Toca «Reanudar» para continuar.', 'The session was paused by a call or another audio app. Tap “Resume” to continue.'],
  'mic_denied': ['Sin permiso de micrófono no podemos transcribir. Puedes activarlo en Ajustes del sistema.', 'Without microphone permission we cannot transcribe. You can enable it in system Settings.'],
  'open_settings': ['Abrir ajustes', 'Open settings'],
  'err_no_entitlement': ['Necesitas un plan activo para iniciar una sesión.', 'You need an active plan to start a session.'],
  'err_trial_used': ['Esta cuenta ya usó su prueba gratuita.', 'This account already used its free trial.'],
  'err_rate_limited': ['Demasiados inicios seguidos. Espera unos minutos.', 'Too many starts in a row. Please wait a few minutes.'],
  'err_capacity': ['Hay mucha demanda ahora. Inténtalo en unos minutos.', 'High demand right now. Please try again in a few minutes.'],

  // Historial
  'history_empty': ['No tienes transcripciones guardadas.', 'You have no saved transcripts.'],
  'delete_transcript_confirm': ['¿Eliminar esta transcripción? No se puede deshacer.', 'Delete this transcript? This cannot be undone.'],
  'translate_this': ['Traducir esta transcripción', 'Translate this transcript'],
  'copy': ['Copiar', 'Copy'],
  'copied': ['Copiado', 'Copied'],

  // Traducción de texto
  'text_cost_rule': [
    'Traducir texto usa tus minutos: 1 minuto por cada 1,000 caracteres (se redondea al minuto siguiente). Antes de procesar verás cuánto usará y podrás cancelar.',
    'Translating text uses your minutes: 1 minute per 1,000 characters (rounded up to the next minute). Before processing you will see how much it will use and can cancel.'
  ],
  'paste_text': ['Pega o escribe el texto', 'Paste or type the text'],
  'direction': ['Dirección', 'Direction'],
  'en_to_es': ['Inglés → Español', 'English → Spanish'],
  'es_to_en': ['Español → Inglés', 'Spanish → English'],
  'calculate_cost': ['Calcular uso de minutos', 'Calculate minute usage'],
  'estimate_msg': ['Esto usará {cost} de tus {remaining} disponibles ({chars} caracteres). ¿Continuar?', 'This will use {cost} of your {remaining} available ({chars} characters). Continue?'],
  'estimate_not_allowed': ['No es posible traducir: {reason}', 'Cannot translate: {reason}'],
  'reason_quota_exhausted': ['minutos insuficientes', 'not enough minutes'],
  'reason_too_long': ['el texto es demasiado largo', 'the text is too long'],
  'reason_empty': ['el texto está vacío', 'the text is empty'],
  'reason_no_entitlement': ['no tienes un plan activo', 'you don’t have an active plan'],
  'result': ['Resultado', 'Result'],

  // Planes
  'plans_title': ['Planes', 'Plans'],
  'plan_personal': ['Plan Personal', 'Personal Plan'],
  'plan_personal_features': [
    '300 minutos por periodo mensual · transcripción y traducción inglés ↔ español · un idioma de traducción a la vez · historial opcional',
    '300 minutes per monthly period · English ↔ Spanish transcription and translation · one translation language at a time · optional history'
  ],
  'minute_counting': ['Un minuto de audio cuenta una sola vez, aunque veas transcripción y traducción juntas. No hay cobros por excedente: al agotar los minutos, el servicio se detiene hasta el siguiente periodo.', 'Each minute of audio counts once, even when you see transcription and translation together. There are no overage charges: when minutes run out, the service stops until the next period.'],
  'trial_offer': [
    'Prueba 7 días sin cobro, con hasta 120 minutos. Después, {price} al mes, con renovación automática, hasta que canceles. Consulta cómo cancelar y las condiciones de la prueba.',
    'Try 7 days free, with up to 120 minutes. Then {price} per month, renewing automatically until you cancel. See how to cancel and the trial terms.'
  ],
  'no_trial_offer': ['{price} al mes, con renovación automática hasta que canceles.', '{price} per month, renewing automatically until you cancel.'],
  'trial_terms': [
    'Si agotas los 120 minutos durante la prueba, no se te cobra antes de tiempo: el uso se detiene hasta que comience el periodo pagado. El primer cobro ocurre al terminar los 7 días, salvo que canceles antes en la tienda.',
    'If you use the 120 minutes during the trial, you are not charged early: usage stops until the paid period starts. The first charge happens when the 7 days end, unless you cancel before in the store.'
  ],
  'how_to_cancel': [
    'Cancela cuando quieras desde la tienda: iPhone → Ajustes → tu nombre → Suscripciones. Android → Google Play → Pagos y suscripciones → Suscripciones.',
    'Cancel anytime from the store: iPhone → Settings → your name → Subscriptions. Android → Google Play → Payments & subscriptions → Subscriptions.'
  ],
  'plan_church': ['Plan Iglesia', 'Church Plan'],
  'plan_church_features': [
    '600 minutos de transmisión por periodo mensual · hasta 30 asistentes simultáneos que reciben el texto sin usar su micrófono · un idioma de traducción por sesión · los minutos no se multiplican por asistentes · incluye el uso personal',
    '600 streaming minutes per monthly period · up to 30 simultaneous attendees who get the text without using their microphone · one translation language per session · minutes are not multiplied by attendees · includes personal use'
  ],
  'plan_church_who': ['Para quien organiza en la iglesia. Los asistentes no necesitan plan ni cuenta.', 'For the church organizer. Attendees need no plan or account.'],
  'church_upgrade_note': [
    'Al cambiar del plan Personal al plan Iglesia, la tienda ajusta el cobro del periodo actual (prorrateo) y el plan Personal deja de renovarse. Los 600 minutos empiezan con el nuevo plan.',
    'When switching from Personal to Church, the store adjusts the charge for the current period (proration) and the Personal plan stops renewing. The 600 minutes start with the new plan.'
  ],
  'church_includes_personal': ['Tu plan Iglesia ya incluye el uso personal.', 'Your Church plan already includes personal use.'],
  'current_plan': ['Plan actual', 'Current plan'],
  'upgrade_to_church': ['Cambiar al plan Iglesia', 'Switch to the Church plan'],
  'plan_name_personal': ['Personal', 'Personal'],
  'plan_name_church': ['Iglesia', 'Church'],
  'plan_name_none': ['Sin plan', 'No plan'],
  'plan': ['Plan', 'Plan'],
  'subscribe': ['Suscribirme', 'Subscribe'],
  'start_trial': ['Comenzar prueba', 'Start trial'],
  'restore': ['Restaurar compras', 'Restore purchases'],
  'restore_none': ['No encontramos compras para restaurar.', 'No purchases found to restore.'],
  'purchase_done': ['¡Listo! Tu plan está activo.', 'Done! Your plan is active.'],
  'purchase_pending': ['La compra está pendiente de confirmación de la tienda.', 'The purchase is pending store confirmation.'],
  'store_unavailable': ['No se pudieron cargar los productos de la tienda.', 'Could not load store products.'],
  'terms': ['Términos de uso', 'Terms of use'],
  'privacy_policy': ['Política de privacidad', 'Privacy policy'],

  // Suscripción
  'subscription': ['Mi suscripción', 'My subscription'],
  'status': ['Estado', 'Status'],
  'status_trial': ['Prueba gratuita', 'Free trial'],
  'status_active': ['Activa', 'Active'],
  'status_cancelled_active': ['Cancelada (activa hasta fin del periodo)', 'Cancelled (active until period end)'],
  'status_billing_issue': ['Problema con el pago: actualiza tu método de pago en la tienda', 'Payment problem: update your payment method in the store'],
  'status_grace': ['Periodo de gracia: actualiza tu método de pago en la tienda', 'Grace period: update your payment method in the store'],
  'status_expired': ['Vencida', 'Expired'],
  'status_refunded': ['Reembolsada', 'Refunded'],
  'status_none': ['Sin plan', 'No plan'],
  'manage_in_store': ['Administrar o cancelar en la tienda', 'Manage or cancel in the store'],
  'minutes_used': ['Minutos usados', 'Minutes used'],
  'when_out_of_minutes': ['Al agotar tus minutos puedes esperar a la renovación. No hay cargos automáticos por minutos extra.', 'When you run out of minutes you can wait for the renewal. There are no automatic charges for extra minutes.'],

  // Ajustes
  'appearance': ['Apariencia', 'Appearance'],
  'text_size': ['Tamaño de letra', 'Text size'],
  'high_contrast': ['Alto contraste', 'High contrast'],
  'theme': ['Tema', 'Theme'],
  'theme_system': ['Sistema', 'System'],
  'theme_light': ['Claro', 'Light'],
  'theme_dark': ['Oscuro', 'Dark'],
  'keep_screen_on': ['Mantener la pantalla encendida durante la sesión', 'Keep the screen on during sessions'],
  'retention': ['Conservar transcripciones guardadas', 'Keep saved transcripts for'],
  'days': ['días', 'days'],
  'account': ['Cuenta', 'Account'],
  'sign_out': ['Cerrar sesión', 'Sign out'],
  'delete_account': ['Eliminar cuenta', 'Delete account'],
  'delete_account_warning': [
    'Se borrarán tu cuenta, transcripciones, glosario e historial de uso. Esto NO cancela tu suscripción: cancélala primero en la tienda para evitar nuevos cobros.',
    'Your account, transcripts, glossary and usage history will be deleted. This does NOT cancel your subscription: cancel it first in the store to avoid new charges.'
  ],
  'delete_account_done': ['Tu cuenta fue eliminada.', 'Your account was deleted.'],
  'glossary': ['Glosario', 'Glossary'],
  'glossary_desc': ['Términos que quieres traducir siempre de cierta forma.', 'Terms you always want translated a certain way.'],
  'add_term': ['Agregar término', 'Add term'],
  'term_source': ['Término original', 'Original term'],
  'term_target': ['Traducción', 'Translation'],
  'default_terms': ['Términos predeterminados', 'Default terms'],
  'my_terms': ['Mis términos', 'My terms'],

  // Ayuda
  'help_internet': ['¿Funciona sin internet? No. La transcripción y la traducción se procesan en servidores; sin conexión no hay subtítulos.', 'Does it work offline? No. Transcription and translation run on servers; without a connection there are no captions.'],
  'help_background': ['¿Funciona con la pantalla apagada o en segundo plano? No en esta versión: la sesión se pausa y debes tocar «Reanudar». Usa «Mantener la pantalla encendida».', 'Does it work with the screen off or in the background? Not in this version: the session pauses and you must tap “Resume”. Use “Keep the screen on”.'],
  'help_accuracy': ['¿Es exacta? Es automática: puede equivocarse con nombres, acentos, ruido o música. Las palabras no entendidas se marcan con [?].', 'Is it accurate? It is automatic: it can make mistakes with names, accents, noise or music. Words not understood are marked with [?].'],
  'help_bible': ['La app no inserta textos bíblicos: muestra lo que dice el predicador.', 'The app does not insert Bible texts: it shows what the preacher says.'],
  'help_contact': ['Contacto de soporte', 'Support contact'],

  // Iglesia
  'church_title': ['Modo iglesia', 'Church mode'],
  'church_join': ['Unirme a una sesión', 'Join a session'],
  'church_join_desc': ['Recibe el texto en tu teléfono con el código o QR de tu iglesia. No usa tu micrófono.', 'Get the text on your phone with your church’s code or QR. Does not use your microphone.'],
  'church_organize': ['Organizar (iglesias)', 'Organize (churches)'],
  'church_organize_desc': ['Transmite el audio autorizado del servicio a los asistentes.', 'Stream the authorized service audio to attendees.'],
  'join_without_account': ['¿Tu iglesia te dio un código? Unirme sin cuenta', 'Did your church give you a code? Join without an account'],
  'join_title': ['Unirme con código', 'Join with a code'],
  'join_code_label': ['Código (por ejemplo ABCD-2345)', 'Code (for example ABCD-2345)'],
  'join_button': ['Unirme', 'Join'],
  'scan_qr': ['Escanear código QR', 'Scan QR code'],
  'scan_qr_hint': ['Apunta la cámara al código QR que muestra tu iglesia. La cámara solo se usa para leer el código.', 'Point the camera at the QR code shown by your church. The camera is only used to read the code.'],
  'join_invalid_code': ['Código no válido, vencido o de una sesión terminada.', 'Invalid or expired code, or the session has ended.'],
  'join_session_full': ['La sesión alcanzó el máximo de asistentes.', 'The session has reached its attendee limit.'],
  'join_disabled': ['El modo iglesia no está disponible por ahora.', 'Church mode is not available right now.'],
  'listener_no_mic': ['Solo recibes texto: tu micrófono no se usa.', 'You only receive text: your microphone is not used.'],
  'listener_waiting': ['Esperando a que el organizador inicie la transmisión…', 'Waiting for the organizer to start streaming…'],
  'listener_interrupted': ['La transmisión se interrumpió. Esperando a que el organizador vuelva…', 'The stream was interrupted. Waiting for the organizer to return…'],
  'listener_ended': ['La sesión terminó. Gracias por acompañarnos.', 'The session has ended. Thank you for joining.'],
  'leave': ['Salir', 'Leave'],
  'orgs_title': ['Mis iglesias', 'My churches'],
  'orgs_empty': ['Todavía no perteneces a ninguna iglesia en FaithBridge.', 'You don’t belong to any church on FaithBridge yet.'],
  'create_org': ['Registrar mi iglesia', 'Register my church'],
  'org_name': ['Nombre de la iglesia', 'Church name'],
  'attest_title': ['Autorización del audio', 'Audio authorization'],
  'attest_text': [
    'Confirmo que tengo autorización de la iglesia para transmitir y procesar este audio, que se avisará a los asistentes y que revisaremos las reglas de grabación y privacidad que apliquen en nuestro lugar.',
    'I confirm I am authorized by the church to stream and process this audio, that attendees will be informed, and that we will review the recording and privacy rules that apply where we are.'
  ],
  'org_sessions': ['Sesiones', 'Sessions'],
  'new_session': ['Nueva sesión', 'New session'],
  'max_listeners': ['Máximo de asistentes', 'Maximum attendees'],
  'church_save_desc': ['Se guardará para los miembros de la iglesia.', 'It will be saved for the church’s members.'],
  'session_code_title': ['Código para los asistentes', 'Code for attendees'],
  'session_code_help': ['Muéstralo en pantalla o compártelo. Solo se muestra ahora: guárdalo. Vence el', 'Show it on screen or share it. It is shown only now: keep it. Expires on'],
  'start_broadcast': ['Iniciar transmisión', 'Start streaming'],
  'end_session': ['Terminar sesión', 'End session'],
  'end_session_confirm': ['¿Terminar la sesión para todos los asistentes?', 'End the session for all attendees?'],
  'members': ['Miembros', 'Members'],
  'add_member': ['Agregar miembro', 'Add member'],
  'member_email': ['Correo (la persona debe tener cuenta en FaithBridge)', 'Email (the person must have a FaithBridge account)'],
  'role_owner': ['Propietario', 'Owner'],
  'role_admin': ['Administrador', 'Admin'],
  'role_member': ['Miembro', 'Member'],
  'member_not_found': ['No existe una cuenta con ese correo.', 'There is no account with that email.'],
  'usage_title': ['Uso del periodo', 'Usage this period'],
  'usage_broadcast': ['Transmisión', 'Streaming'],
  'usage_peak': ['Máximo de asistentes simultáneos', 'Peak simultaneous attendees'],
  'listeners_count': ['Asistentes', 'Attendees'],
  'no_church_plan': ['Para transmitir necesitas el plan Iglesia activo.', 'You need an active Church plan to stream.'],
  'session_scheduled': ['Lista para transmitir', 'Ready to stream'],
  'session_live': ['Transmitiendo', 'Streaming'],
  'session_ended': ['Terminada', 'Ended'],
  'reopen_broadcast': ['Transmitir', 'Stream'],
  'church_body': [
    'Estamos preparando un modo para que tu iglesia transmita el audio autorizado de su sistema de sonido y los asistentes reciban el texto en sus teléfonos sin usar su micrófono. Aún no está disponible.',
    'We are preparing a mode so your church can stream authorized audio from its sound system and attendees receive the text on their phones without using their microphone. It is not available yet.'
  ],
};

class S {
  S(this.code);
  final String code;

  static S of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return S(locale.languageCode == 'en' ? 'en' : 'es');
  }

  bool get isEs => code == 'es';

  String t(String key, [Map<String, String> args = const {}]) {
    final pair = kStrings[key];
    var s = pair == null ? key : pair[isEs ? 0 : 1];
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }
}
