/// Para quién es visible un módulo.
enum ModuleAudience {
  /// App del titular.
  cardholder('CARDHOLDER', 'Titular');

  const ModuleAudience(this.wireName, this.label);

  /// Nombre en el JSON.
  final String wireName;

  /// Nombre para mostrar.
  final String label;
}

/// Módulos de la aplicación que administración puede activar o desactivar.
///
/// La base guarda solo si cada módulo está encendido (`app_modules`); el
/// nombre y la descripción viven aquí para que API y app digan lo mismo.
/// Con un módulo apagado la app oculta la función y la API responde
/// `MODULE_DISABLED` aunque alguien llame a la ruta directamente.
///
/// Las operaciones de dinero de la caja y el reporte de pérdida **no** son
/// módulos: siempre están disponibles (ver docs/adr/0014).
enum AppModule {
  /// Asistente virtual (chatbot) que responde dudas del titular.
  assistant(
    'assistant',
    'Asistente virtual',
    'Chat que responde dudas del titular: saldo, recargas, pagos, PIN y '
        'pérdida de la tarjeta.',
  ),

  /// Registro de titulares desde la app.
  selfRegistration(
    'self_registration',
    'Registro de titulares',
    'Permite que una persona cree su cuenta desde la app y verifique su '
        'correo.',
  ),

  /// Pago del titular en caja con el código de la caja.
  holderPayments(
    'holder_payments',
    'Pago con código de caja',
    'El titular paga desde su celular escribiendo el código que muestra la '
        'caja.',
  ),

  /// Código QR de la tarjeta en el celular del titular.
  cardQr(
    'card_qr',
    'QR de la tarjeta',
    'Muestra la tarjeta como código QR para que la caja la lea con la '
        'cámara.',
  ),

  /// Cambio de PIN desde la app.
  pinChange(
    'pin_change',
    'Cambio de PIN',
    r'El titular cambia el PIN que pide la caja en compras de más de $25.',
  );

  const AppModule(this.key, this.label, this.description);

  /// Llave en la base y en el JSON.
  final String key;

  /// Nombre para mostrar.
  final String label;

  /// Qué hace el módulo, en una frase.
  final String description;

  /// Quién usa el módulo (por ahora, todos son del titular).
  ModuleAudience get audience => ModuleAudience.cardholder;

  /// Busca un módulo por su [key]; `null` si no existe.
  static AppModule? fromKey(String key) =>
      AppModule.values.where((m) => m.key == key).firstOrNull;
}
