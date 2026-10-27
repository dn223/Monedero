import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';

/// Columnas agrupadas de recargas y cobros por día (últimos 14 días).
///
/// Sigue las reglas del skill de visualización: un solo eje, columnas de
/// máximo 24 px con la punta redondeada (4 px) y la base recta, 2 px de aire
/// entre columnas vecinas, cuadrícula tenue, leyenda siempre visible (dos
/// series), texto en colores de texto (nunca en el color de la serie),
/// detalle al pasar el mouse o tocar, y vista de tabla como alternativa.
class DailyChart extends StatefulWidget {
  /// Crea el gráfico con [days] (`day`, `topUpCents`, `debitCents`,
  /// `operations`).
  const DailyChart({required this.days, super.key});

  /// Serie diaria de la API.
  final List<Map<String, Object?>> days;

  @override
  State<DailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<DailyChart> {
  int? _selected;
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: palette.topUp, label: 'Recargas'),
            const SizedBox(width: 16),
            _LegendDot(color: palette.debit, label: 'Cobros'),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _table = !_table),
              icon: Icon(
                _table ? Icons.bar_chart_rounded : Icons.table_rows_outlined,
              ),
              label: Text(_table ? 'Ver gráfico' : 'Ver tabla'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_table)
          _DailyTable(days: widget.days)
        else
          SizedBox(
            height: 240,
            child: LayoutBuilder(
              builder: (context, box) {
                final geometry = _Geometry(widget.days, box.biggest);
                final selected = _selected;
                return MouseRegion(
                  onHover: (e) => setState(
                    () => _selected = geometry.indexAt(e.localPosition),
                  ),
                  onExit: (_) => setState(() => _selected = null),
                  child: GestureDetector(
                    onTapDown: (e) => setState(
                      () => _selected = geometry.indexAt(e.localPosition),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          size: box.biggest,
                          painter: _ChartPainter(
                            geometry: geometry,
                            selected: selected,
                            topUp: palette.topUp,
                            debit: palette.debit,
                            surface: theme.colorScheme.surfaceContainerLow,
                            grid: theme.colorScheme.outlineVariant,
                            highlight: theme.colorScheme.onSurface.withValues(
                              alpha: 0.06,
                            ),
                            labelStyle: AppText.money(
                              theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        if (selected != null)
                          _Tooltip(
                            day: widget.days[selected],
                            anchorX: geometry.centerOf(selected),
                            band: geometry.band,
                            width: box.maxWidth,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Medidas compartidas por el pintor y la detección del toque.
class _Geometry {
  _Geometry(this.days, this.size) {
    final peak = days.fold<int>(
      0,
      (m, d) => math.max(
        m,
        math.max(d['topUpCents']! as int, d['debitCents']! as int),
      ),
    );
    step = _niceStep(peak);
    top = step * 4;
  }

  final List<Map<String, Object?>> days;
  final Size size;

  /// Espacio para las etiquetas del eje Y (izquierda) y X (abajo).
  static const double left = 44;
  static const double bottom = 24;
  static const double topPad = 8;

  late final int step;
  late final int top;

  double get plotWidth => size.width - left;
  double get plotHeight => size.height - bottom - topPad;
  double get band => plotWidth / days.length;

  /// Ancho de cada columna: máximo 24 px y nunca llena la banda.
  double get barWidth => math.min(24.0, (band * 0.7 - 2) / 2).clamp(2.0, 24.0);

  double centerOf(int i) => left + band * (i + 0.5);

  /// Posición vertical (píxeles) de un valor del eje, en centavos.
  double yOf(int value) =>
      topPad + plotHeight - (top == 0 ? 0 : plotHeight * value / top);

  int? indexAt(Offset p) {
    if (p.dx < left) return null;
    final i = ((p.dx - left) / band).floor();
    return i >= 0 && i < days.length ? i : null;
  }

  /// Paso "bonito" del eje en centavos (1, 2 o 5 × 10ⁿ dólares) para que
  /// cuatro líneas cubran el máximo.
  static int _niceStep(int peakCents) {
    if (peakCents <= 0) return 500;
    var magnitude = 100;
    while (magnitude * 10 * 4 <= peakCents) {
      magnitude *= 10;
    }
    for (final m in const [1, 2, 5, 10]) {
      if (magnitude * m * 4 >= peakCents) return magnitude * m;
    }
    return magnitude * 10;
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.geometry,
    required this.selected,
    required this.topUp,
    required this.debit,
    required this.surface,
    required this.grid,
    required this.highlight,
    required this.labelStyle,
  });

  final _Geometry geometry;
  final int? selected;
  final Color topUp;
  final Color debit;
  final Color surface;
  final Color grid;
  final Color highlight;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    // Cuadrícula y etiquetas del eje Y (dólares enteros).
    for (var i = 0; i <= 4; i++) {
      final cents = g.step * i;
      final y = g.yOf(cents);
      canvas.drawLine(
        Offset(_Geometry.left, y),
        Offset(size.width, y),
        gridPaint,
      );
      _text(
        canvas,
        '\$${cents ~/ 100}',
        Offset(_Geometry.left - 6, y),
        alignRight: true,
      );
    }

    // Banda de la columna seleccionada.
    final s = selected;
    if (s != null) {
      canvas.drawRect(
        Rect.fromLTWH(
          _Geometry.left + g.band * s,
          _Geometry.topPad,
          g.band,
          g.plotHeight,
        ),
        Paint()..color = highlight,
      );
    }

    // Columnas: recarga a la izquierda, cobro a la derecha, 2 px de aire.
    final w = g.barWidth;
    for (var i = 0; i < g.days.length; i++) {
      final d = g.days[i];
      final cx = g.centerOf(i);
      _bar(canvas, cx - 1 - w, w, d['topUpCents']! as int, topUp);
      _bar(canvas, cx + 1, w, d['debitCents']! as int, debit);
    }

    // Etiquetas del eje X: cada dos días si no caben todas.
    final every = g.band < 44 ? 2 : 1;
    for (var i = g.days.length - 1; i >= 0; i -= every) {
      _text(
        canvas,
        Fmt.shortDay(g.days[i]['day']! as String),
        Offset(g.centerOf(i), size.height - _Geometry.bottom + 6),
        center: true,
      );
    }
  }

  void _bar(Canvas canvas, double x, double w, int value, Color color) {
    if (value <= 0) return;
    final y = geometry.yOf(value);
    final base = geometry.yOf(0);
    final rect = Rect.fromLTRB(x, y, x + w, base);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      ),
      Paint()..color = color,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    bool alignRight = false,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? at.dx - painter.width
        : center
        ? at.dx - painter.width / 2
        : at.dx;
    final dy = center ? at.dy : at.dy - painter.height / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.selected != selected ||
      old.geometry.size != geometry.size ||
      old.geometry.days != geometry.days ||
      old.topUp != topUp;
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.day,
    required this.anchorX,
    required this.band,
    required this.width,
  });

  final Map<String, Object?> day;
  final double anchorX;
  final double band;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    const boxWidth = 168.0;
    // A la derecha de la columna; si no cabe, a la izquierda.
    final right = anchorX + band / 2 + 8;
    final left = right + boxWidth <= width
        ? right
        : (anchorX - band / 2 - 8 - boxWidth).clamp(0.0, width - boxWidth);
    Widget row(Color color, String label, int cents) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(label)),
          Text(Money.format(cents), style: AppText.money(null)),
        ],
      ),
    );
    return Positioned(
      left: left,
      top: 0,
      width: boxWidth,
      child: IgnorePointer(
        child: Material(
          elevation: 3,
          color: theme.colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: DefaultTextStyle(
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onInverseSurface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Fmt.shortDay(day['day']! as String),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  row(palette.topUp, 'Recargas', day['topUpCents']! as int),
                  row(palette.debit, 'Cobros', day['debitCents']! as int),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('${day['operations']} operaciones'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _DailyTable extends StatelessWidget {
  const _DailyTable({required this.days});

  final List<Map<String, Object?>> days;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowHeight: 40,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 40,
      columns: const [
        DataColumn(label: Text('Día')),
        DataColumn(label: Text('Recargas'), numeric: true),
        DataColumn(label: Text('Cobros'), numeric: true),
        DataColumn(label: Text('Operaciones'), numeric: true),
      ],
      rows: [
        for (final d in days.reversed)
          DataRow(
            cells: [
              DataCell(Text(Fmt.shortDay(d['day']! as String))),
              DataCell(Text(Money.format(d['topUpCents']! as int))),
              DataCell(Text(Money.format(d['debitCents']! as int))),
              DataCell(Text('${d['operations']}')),
            ],
          ),
      ],
    ),
  );
}
