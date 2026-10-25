import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../brand/brand.dart';

/// Anchos de pantalla a partir de los cuales cambia la distribución.
abstract final class Breakpoints {
  /// Desde aquí hay espacio para dos columnas (tableta, escritorio).
  static const double wide = 900;

  /// `true` si el ancho disponible permite dos columnas.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;
}

/// Esqueleto de las pantallas de cada rol: barra con regreso al inicio,
/// título con el ícono del rol y contenido centrado con ancho máximo.
class RoleScaffold extends StatelessWidget {
  /// Crea la pantalla.
  const RoleScaffold({
    required this.title,
    required this.icon,
    required this.body,
    this.actions = const [],
    this.maxWidth = 1100,
    this.bottomNavigationBar,
    super.key,
  });

  /// Título de la barra.
  final String title;

  /// Ícono del rol.
  final IconData icon;

  /// Contenido (normalmente desplazable).
  final Widget body;

  /// Acciones de la barra (por ejemplo, cerrar sesión).
  final List<Widget> actions;

  /// Ancho máximo del contenido.
  final double maxWidth;

  /// Barra inferior opcional (navegación de administración en celular).
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Inicio',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 10),
            Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [...actions, const SizedBox(width: 8)],
      ),
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Lista desplazable con el relleno estándar de las pantallas.
class PageList extends StatelessWidget {
  /// Crea la lista.
  const PageList({required this.children, super.key});

  /// Contenido.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
      vertical: 16,
    ),
    children: children,
  );
}

/// Dos columnas en pantallas anchas; una sola, apilada, en celular.
class TwoColumns extends StatelessWidget {
  /// Crea la distribución.
  const TwoColumns({
    required this.start,
    required this.end,
    this.startFlex = 5,
    this.endFlex = 4,
    super.key,
  });

  /// Columna principal (izquierda, o arriba en celular).
  final List<Widget> start;

  /// Columna secundaria (derecha, o abajo en celular).
  final List<Widget> end;

  /// Proporción de la columna principal.
  final int startFlex;

  /// Proporción de la columna secundaria.
  final int endFlex;

  @override
  Widget build(BuildContext context) {
    if (!Breakpoints.isWide(context)) {
      return PageList(children: [...start, const SizedBox(height: 8), ...end]);
    }
    Widget column(List<Widget> children) => ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      children: children,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: startFlex, child: column(start)),
          Expanded(flex: endFlex, child: column(end)),
        ],
      ),
    );
  }
}

/// Título de sección.
class SectionTitle extends StatelessWidget {
  /// Crea el título; [trailing] va alineado a la derecha.
  const SectionTitle(this.text, {this.trailing, super.key});

  /// Texto.
  final String text;

  /// Widget opcional a la derecha (por ejemplo, un botón).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Pantalla vacía o de bienvenida con ícono, texto y una acción.
class EmptyState extends StatelessWidget {
  /// Crea el estado vacío.
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  /// Ícono grande.
  final IconData icon;

  /// Título.
  final String title;

  /// Explicación con el siguiente paso.
  final String message;

  /// Acción opcional.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Logotipo y nombre de la app en una línea.
class BrandMark extends StatelessWidget {
  /// Crea la marca.
  const BrandMark({this.size = 28, super.key});

  /// Tamaño del logotipo.
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Brand.logo(size: size, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          Brand.appName,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
      ],
    );
  }
}
