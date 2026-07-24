import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/geometry_utils.dart';
import '../../data/models/relationship_model.dart';
import '../../data/models/table_model.dart';
import '../../state/canvas_provider.dart';
import '../../state/canvas_state.dart';
import '../../state/schemas_provider.dart';
import '../painters/dragging_connection_painter.dart';
import '../painters/grid_painter.dart';
import '../painters/orthogonal_connection_painter.dart';
import '../widgets/header_toolbar.dart';
import '../widgets/property_sidebar.dart';
import '../widgets/relationship_dialog.dart';
import '../widgets/schemas_sidebar.dart';
import '../widgets/table_card_widget.dart';

class MainDesignerScreen extends ConsumerStatefulWidget {
  const MainDesignerScreen({super.key});

  @override
  ConsumerState<MainDesignerScreen> createState() => _MainDesignerScreenState();
}

class _MainDesignerScreenState extends ConsumerState<MainDesignerScreen> {
  late final TransformationController _transformationController;
  final GlobalKey _canvasKey = GlobalKey();
  double _currentScale = 1.0;
  bool _initialSchemaLoaded = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
  }

  void _loadActiveSchema() {
    final schemasState = ref.read(schemasProvider);
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final activeSchema = schemasState.activeSchema;

    if (activeSchema != null && activeSchema.tables.isNotEmpty) {
      canvasNotifier.importDdlResult(
        activeSchema.tables,
        activeSchema.relationships,
      );
    } else if (activeSchema != null && activeSchema.tables.isEmpty) {
      // Esquema vazio (novo) — criar dados de exemplo e salvar
      canvasNotifier.createSampleData();
      ref.read(schemasProvider.notifier).updateActiveSchemaData(
        activeSchema.copyWith(
          tables: ref.read(canvasProvider).tables,
          relationships: ref.read(canvasProvider).relationships,
        ),
      );
    }

    _initialSchemaLoaded = true;
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  Offset _globalToCanvas(Offset globalPosition) {
    final RenderBox? renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return globalPosition;
    final Offset localViewport = renderBox.globalToLocal(globalPosition);
    final Matrix4 inverse =
        Matrix4.tryInvert(_transformationController.value) ?? Matrix4.identity();
    return MatrixUtils.transformPoint(inverse, localViewport);
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.001) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _zoomByFactor(double factor) {
    final double targetScale = (_currentScale * factor).clamp(0.2, 3.0);
    final double effectiveFactor = targetScale / _currentScale;

    final Size viewportSize = MediaQuery.of(context).size;
    final Offset center = Offset(
      viewportSize.width / 2,
      viewportSize.height / 2,
    );

    final Matrix4 translation = Matrix4.translationValues(
      center.dx,
      center.dy,
      0,
    );
    final Matrix4 scaling = Matrix4.identity()
      // ignore: deprecated_member_use
      ..scale(effectiveFactor, effectiveFactor);
    final Matrix4 inverseTranslation = Matrix4.translationValues(
      -center.dx,
      -center.dy,
      0,
    );

    final Matrix4 transformation = translation * scaling * inverseTranslation;
    _transformationController.value =
        transformation * _transformationController.value;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _fitView() {
    final tables = ref.read(canvasProvider).tables;
    if (tables.isEmpty) {
      _resetZoom();
      return;
    }
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final t in tables) {
      minX = math.min(minX, t.position.dx);
      minY = math.min(minY, t.position.dy);
      maxX = math.max(maxX, t.position.dx + 240.0);
      final height = 44.0 + (t.columns.length * 30.0) + 8.0;
      maxY = math.max(maxY, t.position.dy + height);
    }

    final contentWidth = maxX - minX;
    final contentHeight = maxY - minY;
    final centerX = minX + contentWidth / 2;
    final centerY = minY + contentHeight / 2;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final viewportSize = renderBox?.size ?? const Size(1000, 700);

    final double dx = (viewportSize.width / 2) - centerX;
    final double dy = (viewportSize.height / 2) - centerY;

    _transformationController.value = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(dx, dy)
      // ignore: deprecated_member_use
      ..scale(1.0);
  }

  // Estado de arraste interativo de linha de conexão (FK)
  String? _dragSourceTableId;
  String? _dragSourceColumnId;
  Offset? _dragConnectionStartCanvas;
  Offset? _dragConnectionCurrentCanvas;

  Offset _getSourceColumnAnchor(
    String tableId,
    String columnId,
    Offset mouseCanvas,
  ) {
    final canvasState = ref.read(canvasProvider);
    final table = canvasState.tables.firstWhere(
      (t) => t.id == tableId,
      orElse: () => TableModel(
        id: '',
        name: '',
        position: Offset.zero,
        columns: [],
      ),
    );
    if (table.id.isEmpty) return mouseCanvas;

    final colIndex = table.columns.indexWhere((c) => c.id == columnId);
    final idx = colIndex >= 0 ? colIndex : 0;
    final colY = table.position.dy + 44.0 + (idx * 30.0) + 15.0;

    final isRight = mouseCanvas.dx >= (table.position.dx + 130.0);
    final colX = isRight ? (table.position.dx + 260.0) : table.position.dx;

    return Offset(colX, colY);
  }

  void _onConnectStart(
    String sourceTableId,
    String sourceColumnId,
    Offset globalPos,
  ) {
    final mouseCanvas = _globalToCanvas(globalPos);
    _dragSourceTableId = sourceTableId;
    _dragSourceColumnId = sourceColumnId;
    final startAnchor = _getSourceColumnAnchor(
      sourceTableId,
      sourceColumnId,
      mouseCanvas,
    );
    setState(() {
      _dragConnectionStartCanvas = startAnchor;
      _dragConnectionCurrentCanvas = mouseCanvas;
    });
  }

  void _onConnectUpdate(Offset globalPos) {
    if (_dragConnectionStartCanvas == null ||
        _dragSourceTableId == null ||
        _dragSourceColumnId == null) {
      return;
    }
    final mouseCanvas = _globalToCanvas(globalPos);
    final startAnchor = _getSourceColumnAnchor(
      _dragSourceTableId!,
      _dragSourceColumnId!,
      mouseCanvas,
    );
    setState(() {
      _dragConnectionStartCanvas = startAnchor;
      _dragConnectionCurrentCanvas = mouseCanvas;
    });
  }

  void _onConnectEnd(
    String sourceTableId,
    String sourceColumnId,
    Offset globalPos,
  ) {
    if (_dragConnectionStartCanvas == null) return;
    final dropCanvasPoint = _globalToCanvas(globalPos);

    setState(() {
      _dragSourceTableId = null;
      _dragSourceColumnId = null;
      _dragConnectionStartCanvas = null;
      _dragConnectionCurrentCanvas = null;
    });

    final canvasState = ref.read(canvasProvider);

    // Identificar a tabela de destino sob o cursor do mouse
    TableModel? targetTable;
    String? initialTargetColumnId;

    for (final t in canvasState.tables) {
      if (t.id == sourceTableId) continue;
      final height = 44.0 + (t.columns.length * 30.0) + 8.0;
      final rect = Rect.fromLTWH(t.position.dx, t.position.dy, 260.0, height);

      if (rect.contains(dropCanvasPoint)) {
        targetTable = t;

        // Verificar se foi solto sobre uma coluna específica
        final relativeY = dropCanvasPoint.dy - (t.position.dy + 44.0);
        if (relativeY >= 0) {
          final colIndex = (relativeY / 30.0).floor();
          if (colIndex >= 0 && colIndex < t.columns.length) {
            initialTargetColumnId = t.columns[colIndex].id;
          }
        }
        break;
      }
    }

    if (targetTable != null) {
      _openRelationshipDialog(
        sourceTableId: sourceTableId,
        sourceColumnId: sourceColumnId,
        targetTableId: targetTable.id,
        initialTargetColumnId: initialTargetColumnId,
      );
    }
  }

  RelationshipModel? _findRelationshipAt(
    Offset canvasPoint,
    CanvasState state,
    Map<String, Rect> tableRects,
  ) {
    for (final rel in state.relationships) {
      final sourceRect = tableRects[rel.sourceTableId];
      final targetRect = tableRects[rel.targetTableId];
      if (sourceRect == null || targetRect == null) continue;

      final (sourceAnchor, targetAnchor) =
          GeometryUtils.getBestAnchorPair(sourceRect, targetRect);
      final points =
          GeometryUtils.calculateOrthogonalPath(sourceAnchor, targetAnchor);

      for (int i = 0; i < points.length - 1; i++) {
        final dist = _distanceToSegment(canvasPoint, points[i], points[i + 1]);
        if (dist <= 16.0) {
          return rel;
        }
      }
    }
    return null;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final l2 = (a - b).distanceSquared;
    if (l2 == 0) return (p - a).distance;
    double t =
        ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2;
    t = t.clamp(0.0, 1.0);
    final projection = Offset(
      a.dx + t * (b.dx - a.dx),
      a.dy + t * (b.dy - a.dy),
    );
    return (p - projection).distance;
  }

  void _openRelationshipDialog({
    required String sourceTableId,
    required String sourceColumnId,
    required String targetTableId,
    String? initialTargetColumnId,
    RelationshipModel? existingRelationship,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => RelationshipDialog(
        sourceTableId: sourceTableId,
        sourceColumnId: sourceColumnId,
        targetTableId: targetTableId,
        initialTargetColumnId: initialTargetColumnId,
        existingRelationship: existingRelationship,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Carregar esquema ativo no canvas quando os schemas terminarem de carregar do disco
    ref.listen<SchemasState>(schemasProvider, (previous, next) {
      if (!_initialSchemaLoaded && next.schemas.isNotEmpty) {
        _loadActiveSchema();
      }
    });

    ref.listen<CanvasState>(canvasProvider, (previous, next) {
      if (previous != next && _initialSchemaLoaded) {
        final activeSchema = ref.read(schemasProvider).activeSchema;
        if (activeSchema != null) {
          ref.read(schemasProvider.notifier).updateActiveSchemaData(
                activeSchema.copyWith(
                  tables: next.tables,
                  relationships: next.relationships,
                  activeDialect: next.activeDialect,
                ),
              );
        }
      }
    });

    final canvasState = ref.watch(canvasProvider);
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gridColor = isDark ? AppColors.darkGridLine : AppColors.lightGridLine;
    final canvasBg = isDark
        ? AppColors.darkCanvasBackground
        : AppColors.lightCanvasBackground;
    final lineColor = isDark ? AppColors.darkLine : AppColors.lightLine;

    // Calcular caixas delimitadoras (Rect) de cada tabela no espaço do canvas
    final Map<String, Rect> tableRects = {};
    for (final t in canvasState.tables) {
      final height = 44.0 + (t.columns.length * 30.0) + 8.0;
      tableRects[t.id] = Rect.fromLTWH(
        t.position.dx,
        t.position.dy,
        240.0,
        height,
      );
    }

    return Scaffold(
      backgroundColor: canvasBg,
      body: Column(
        children: [
          // Header / Toolbar superior
          const HeaderToolbar(),

          // Banner de aviso durante o Modo de Conexão
          if (canvasState.isConnectingMode)
            Container(
              color: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Modo de Conexão Ativo: Clique na tabela de destino para criar um relacionamento.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => canvasNotifier.cancelConnectionMode(),
                    child: const Text(
                      'CANCELAR',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // Área de trabalho do Canvas Interativo (Pan & Zoom) e Sidebars
          Expanded(
            child: Row(
              children: [
                // Sidebar Lateral Esquerda (Esquemas / Projetos)
                const SchemasSidebar(),

                // Canvas Principal Interativo
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      children: [
                        // Mesa com suporte a Zoom e Pan
                        InteractiveViewer(
                          key: _canvasKey,
                          transformationController: _transformationController,
                          minScale: 0.2,
                          maxScale: 3.0,
                          boundaryMargin: const EdgeInsets.all(3000),
                          constrained: false,
                          child: SizedBox(
                            width: 4000,
                            height: 4000,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) {
                                final canvasPoint =
                                    _globalToCanvas(details.globalPosition);
                                final hitRel = _findRelationshipAt(
                                  canvasPoint,
                                  canvasState,
                                  tableRects,
                                );
                                if (hitRel != null) {
                                  canvasNotifier.selectRelationship(hitRel.id);
                                } else {
                                  canvasNotifier.selectTable(null);
                                  canvasNotifier.selectRelationship(null);
                                }
                              },
                              onDoubleTapDown: (details) {
                                final canvasPoint =
                                    _globalToCanvas(details.globalPosition);
                                final hitRel = _findRelationshipAt(
                                  canvasPoint,
                                  canvasState,
                                  tableRects,
                                );
                                if (hitRel != null) {
                                  _openRelationshipDialog(
                                    sourceTableId: hitRel.sourceTableId,
                                    sourceColumnId: hitRel.sourceColumnId,
                                    targetTableId: hitRel.targetTableId,
                                    initialTargetColumnId: hitRel.targetColumnId,
                                    existingRelationship: hitRel,
                                  );
                                }
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Grade de Fundo
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: GridPainter(
                                        gridColor: gridColor,
                                      ),
                                    ),
                                  ),

                                  // Renderizador Ortogonal de Conexões (Linhas 90°)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: OrthogonalConnectionPainter(
                                        relationships:
                                            canvasState.relationships,
                                        tableRects: tableRects,
                                        selectedRelationshipId:
                                            canvasState.selectedRelationshipId,
                                        lineColor: lineColor,
                                        selectedLineColor:
                                            AppColors.selectedLine,
                                        textColor: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),

                                  // Renderização das Tabelas Móveis
                                  ...canvasState.tables.map((t) {
                                    return TableCardWidget(
                                      key: ValueKey(t.id),
                                      table: t,
                                      isSelected:
                                          t.id == canvasState.selectedTableId,
                                      isConnectingSource:
                                          t.id ==
                                          canvasState.connectionSourceTableId,
                                      globalToCanvas: _globalToCanvas,
                                      onConnectStart: (colId, pos) =>
                                          _onConnectStart(t.id, colId, pos),
                                      onConnectUpdate: (pos) =>
                                          _onConnectUpdate(pos),
                                      onConnectEnd: (colId, pos) =>
                                          _onConnectEnd(t.id, colId, pos),
                                      onTap: () {
                                        if (canvasState.isConnectingMode) {
                                          if (canvasState
                                                  .connectionSourceTableId !=
                                              t.id) {
                                            final sourceTable = canvasState
                                                .tables
                                                .firstWhere(
                                                  (st) =>
                                                      st.id ==
                                                      canvasState
                                                          .connectionSourceTableId,
                                                );
                                            final sourceCol =
                                                sourceTable
                                                    .primaryKeys
                                                    .isNotEmpty
                                                ? sourceTable.primaryKeys.first
                                                : sourceTable.columns.first;
                                            final targetCol =
                                                t.primaryKeys.isNotEmpty
                                                ? t.primaryKeys.first
                                                : t.columns.first;

                                            canvasNotifier.completeConnection(
                                              targetTableId: t.id,
                                              sourceColumnId: sourceCol.id,
                                              targetColumnId: targetCol.id,
                                            );
                                          }
                                        } else {
                                          canvasNotifier.selectTable(t.id);
                                        }
                                      },
                                    );
                                  }),

                                  // Renderizador da Linha Temporária durante o Drag
                                  if (_dragConnectionStartCanvas != null &&
                                      _dragConnectionCurrentCanvas != null)
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: DraggingConnectionPainter(
                                          startPoint:
                                              _dragConnectionStartCanvas!,
                                          endPoint:
                                              _dragConnectionCurrentCanvas!,
                                          lineColor: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Barra Flutuante de Controles de Zoom & Recentralização
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(8),
                            color: theme.cardColor.withValues(alpha: 0.9),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.dividerColor.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_rounded,
                                      size: 20,
                                    ),
                                    tooltip: 'Diminuir Zoom (-)',
                                    onPressed: () => _zoomByFactor(1 / 1.2),
                                  ),
                                  InkWell(
                                    onTap: _resetZoom,
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        '${(_currentScale * 100).round()}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 20,
                                    ),
                                    tooltip: 'Aumentar Zoom (+)',
                                    onPressed: () => _zoomByFactor(1.2),
                                  ),
                                  Container(
                                    height: 18,
                                    width: 1,
                                    color: theme.dividerColor,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.fit_screen_rounded,
                                      size: 20,
                                    ),
                                    tooltip: 'Centralizar Diagrama',
                                    onPressed: _fitView,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Painel Lateral de Propriedades
                const PropertySidebar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
