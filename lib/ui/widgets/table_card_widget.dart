import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/column_model.dart';
import '../../data/models/relationship_model.dart';
import '../../data/models/table_model.dart';
import '../../state/canvas_provider.dart';
import '../../state/canvas_state.dart';

class TableCardWidget extends ConsumerStatefulWidget {
  final TableModel table;
  final bool isSelected;
  final bool isConnectingSource;
  final VoidCallback onTap;
  final Offset Function(Offset globalPosition) globalToCanvas;
  final Function(String sourceColumnId, Offset globalPosition)? onConnectStart;
  final Function(Offset globalPosition)? onConnectUpdate;
  final Function(String sourceColumnId, Offset globalPosition)? onConnectEnd;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const TableCardWidget({
    super.key,
    required this.table,
    required this.isSelected,
    required this.isConnectingSource,
    required this.onTap,
    required this.globalToCanvas,
    this.onConnectStart,
    this.onConnectUpdate,
    this.onConnectEnd,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  ConsumerState<TableCardWidget> createState() => _TableCardWidgetState();
}

class _TableCardWidgetState extends ConsumerState<TableCardWidget> {
  Offset? _grabOffset;
  Offset? _lastPanCanvasPoint;
  bool _isConnectingDrag = false;

  // Estado para Edição Inline de Coluna
  String? _editingColumnId;
  late TextEditingController _colNameController;
  late TextEditingController _lengthController;
  late FocusNode _colNameFocusNode;
  String _selectedDataType = 'VARCHAR';

  // Estado para Edição Inline de Nome da Tabela
  bool _isEditingTableName = false;
  late TextEditingController _tableNameController;
  late FocusNode _tableNameFocusNode;

  @override
  void initState() {
    super.initState();
    _colNameController = TextEditingController();
    _lengthController = TextEditingController();
    _tableNameController = TextEditingController();
    _colNameFocusNode = FocusNode();
    _tableNameFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _colNameController.dispose();
    _lengthController.dispose();
    _tableNameController.dispose();
    _colNameFocusNode.dispose();
    _tableNameFocusNode.dispose();
    super.dispose();
  }

  void _startEditingColumn(ColumnModel col, List<String> availableTypes) {
    setState(() {
      _editingColumnId = col.id;
      _colNameController.text = col.name;
      _lengthController.text = col.lengthOrPrecision ?? '';
      _selectedDataType = availableTypes.contains(col.dataType)
          ? col.dataType
          : (availableTypes.isNotEmpty ? availableTypes.first : col.dataType);
    });
    // Solicitar foco no campo de nome após o setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _colNameFocusNode.requestFocus();
      _colNameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _colNameController.text.length,
      );
    });
  }

  void _saveColumnEdit(String tableId, ColumnModel col) {
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final newName = _colNameController.text.trim();
    if (newName.isNotEmpty) {
      final updated = col.copyWith(
        name: newName,
        dataType: _selectedDataType,
        lengthOrPrecision: _lengthController.text.trim().isEmpty
            ? null
            : _lengthController.text.trim(),
      );
      canvasNotifier.updateColumn(tableId, updated);
    }
    setState(() {
      _editingColumnId = null;
    });
  }

  void _cancelColumnEdit() {
    setState(() {
      _editingColumnId = null;
    });
  }

  void _startEditingTableName() {
    setState(() {
      _isEditingTableName = true;
      _tableNameController.text = widget.table.name;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tableNameFocusNode.requestFocus();
      _tableNameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _tableNameController.text.length,
      );
    });
  }

  void _saveTableNameEdit() {
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final newName = _tableNameController.text.trim();
    if (newName.isNotEmpty) {
      canvasNotifier.updateTable(widget.table.copyWith(name: newName));
    }
    setState(() {
      _isEditingTableName = false;
    });
  }

  void _cancelTableNameEdit() {
    setState(() {
      _isEditingTableName = false;
    });
  }

  /// Verifica se uma coluna FK tem incompatibilidade de tipo com a coluna referenciada
  bool _hasFkTypeMismatch(ColumnModel col, CanvasState canvasState) {
    if (!col.isForeignKey) return false;

    // Encontrar o relacionamento onde esta coluna é a FK
    final rel = canvasState.relationships.firstWhere(
      (r) => r.targetTableId == widget.table.id && r.targetColumnId == col.id,
      orElse: () => RelationshipModel(
        id: '',
        sourceTableId: '',
        targetTableId: '',
        sourceColumnId: '',
        targetColumnId: '',
      ),
    );

    if (rel.id.isEmpty) return false;

    // Encontrar a tabela referenciada e sua coluna PK
    final refTable = canvasState.tables.firstWhere(
      (t) => t.id == rel.sourceTableId,
      orElse: () => TableModel(id: '', name: '', position: Offset.zero, columns: []),
    );

    if (refTable.id.isEmpty) return false;

    final refCol = refTable.columns.firstWhere(
      (c) => c.id == rel.sourceColumnId,
      orElse: () => ColumnModel(id: '', name: '', dataType: ''),
    );

    if (refCol.id.isEmpty) return false;

    // Comparar tipos
    return col.dataType != refCol.dataType;
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final availableDataTypes = canvasState.activeDialect.availableDataTypes;

    final headerBgColor = isDark
        ? AppColors.darkTableHeader
        : AppColors.lightTableHeader;
    final cardBgColor = isDark
        ? AppColors.darkTableCard
        : AppColors.lightTableCard;
    final borderColor = widget.isConnectingSource
        ? Colors.amber
        : widget.isSelected
        ? theme.colorScheme.primary
        : isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return Positioned(
      left: widget.table.position.dx,
      top: widget.table.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onPanStart: (details) {
          if (_isConnectingDrag) return;
          final canvasPoint = widget.globalToCanvas(details.globalPosition);
          _grabOffset = canvasPoint - widget.table.position;
          _lastPanCanvasPoint = canvasPoint;
          // Notificar início do arraste
          widget.onDragStart?.call();
          // Se a tabela faz parte de multi-seleção, não limpa a seleção
          if (!canvasState.selectedTableIds.contains(widget.table.id)) {
            widget.onTap();
          }
        },
        onPanUpdate: (details) {
          if (_isConnectingDrag || _grabOffset == null) return;
          final canvasPoint = widget.globalToCanvas(details.globalPosition);

          // Se a tabela faz parte de multi-seleção, mover todas juntas por delta
          if (canvasState.selectedTableIds.contains(widget.table.id)) {
            if (_lastPanCanvasPoint != null) {
              final delta = canvasPoint - _lastPanCanvasPoint!;
              canvasNotifier.updateMultipleTablePositions(delta);
            }
            _lastPanCanvasPoint = canvasPoint;
          } else {
            final newPos = canvasPoint - _grabOffset!;
            canvasNotifier.updateTablePosition(widget.table.id, newPos);
          }
        },
        onPanEnd: (_) {
          _grabOffset = null;
          _lastPanCanvasPoint = null;
          // Notificar fim do arraste
          widget.onDragEnd?.call();
        },
        onPanCancel: () {
          _grabOffset = null;
          _lastPanCanvasPoint = null;
          // Notificar fim do arraste
          widget.onDragEnd?.call();
        },
        child: Material(
          elevation: widget.isSelected ? 8 : 4,
          borderRadius: BorderRadius.circular(8),
          color: Colors.transparent,
          child: Container(
            width: 260,
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
                width: widget.isSelected || widget.isConnectingSource
                    ? 2.5
                    : 1.5,
              ),
              boxShadow: [
                if (widget.isSelected)
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header da Tabela
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: headerBgColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.table_chart_rounded,
                        size: 16,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditingTableName)
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 32,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                      child: GestureDetector(
                                        onDoubleTap: () {
                                          _tableNameController.selection = TextSelection(
                                            baseOffset: 0,
                                            extentOffset: _tableNameController.text.length,
                                          );
                                        },
                                        child: TextField(
                                          controller: _tableNameController,
                                          focusNode: _tableNameFocusNode,
                                          autofocus: false,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onSubmitted: (_) =>
                                              _saveTableNameEdit(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _saveTableNameEdit,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade600,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: _cancelTableNameEdit,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade600,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              GestureDetector(
                                onTap: _startEditingTableName,
                                child: Tooltip(
                                  message: 'Clique para editar nome da tabela',
                                  child: Text(
                                    widget.table.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            if (widget.table.schema.isNotEmpty &&
                                !_isEditingTableName)
                              Text(
                                widget.table.schema,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Botão adicionar coluna rápido
                      InkWell(
                        onTap: () => canvasNotifier.addColumn(widget.table.id),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.add, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de Colunas
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: widget.table.columns.map((col) {
                      final isEditing = _editingColumnId == col.id;

                      if (isEditing) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Linha 1: Nome da Coluna + Botões Salvar e Cancelar
                              Row(
                                children: [
                                  // Campo Nome da Coluna
                                  Expanded(
                                    child: Container(
                                      height: 32,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                      child: GestureDetector(
                                        onDoubleTap: () {
                                          _colNameController.selection = TextSelection(
                                            baseOffset: 0,
                                            extentOffset: _colNameController.text.length,
                                          );
                                        },
                                        child: TextField(
                                          controller: _colNameController,
                                          focusNode: _colNameFocusNode,
                                          autofocus: false,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'Nome da Coluna',
                                            isDense: true,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onSubmitted: (_) => _saveColumnEdit(
                                            widget.table.id,
                                            col,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Botão Salvar (✓)
                                  InkWell(
                                    onTap: () =>
                                        _saveColumnEdit(widget.table.id, col),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade600,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Botão Cancelar (✕)
                                  InkWell(
                                    onTap: _cancelColumnEdit,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade600,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Linha 2: Seletor de Tipo + Campo Tamanho/Precisão
                              Row(
                                children: [
                                  // Seletor de Tipo de Dado
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      height: 32,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value:
                                              availableDataTypes.contains(
                                                _selectedDataType,
                                              )
                                              ? _selectedDataType
                                              : (availableDataTypes.isNotEmpty
                                                    ? availableDataTypes.first
                                                    : col.dataType),
                                          isDense: true,
                                          isExpanded: true,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(
                                                () => _selectedDataType = val,
                                              );
                                            }
                                          },
                                          items: availableDataTypes.map((type) {
                                            return DropdownMenuItem<String>(
                                              value: type,
                                              child: Text(
                                                type,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Campo Tamanho / Precisão (ex: 255 ou 10,2)
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      height: 32,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                      child: GestureDetector(
                                        onDoubleTap: () {
                                          _lengthController.selection = TextSelection(
                                            baseOffset: 0,
                                            extentOffset: _lengthController.text.length,
                                          );
                                        },
                                        child: TextField(
                                          controller: _lengthController,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'Tam (ex: 255)',
                                            isDense: true,
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onSubmitted: (_) => _saveColumnEdit(
                                            widget.table.id,
                                            col,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      final selectedRel = canvasState.selectedRelationship;
                      final isColRelatedToSelectedRel =
                          selectedRel != null &&
                          ((selectedRel.sourceTableId == widget.table.id &&
                                  selectedRel.sourceColumnId == col.id) ||
                              (selectedRel.targetTableId == widget.table.id &&
                                  selectedRel.targetColumnId == col.id));

                      // Verificar incompatibilidade de tipo na FK
                      final hasFkTypeError = _hasFkTypeMismatch(col, canvasState);

                      return GestureDetector(
                        onTap: () =>
                            _startEditingColumn(col, availableDataTypes),
                        behavior: HitTestBehavior.opaque,
                        child: Tooltip(
                          message: hasFkTypeError
                              ? 'Tipo incompatível com a coluna referenciada!'
                              : isColRelatedToSelectedRel
                              ? 'Coluna vinculada ao relacionamento selecionado'
                              : 'Clique para editar nome e tipo',
                          waitDuration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: hasFkTypeError
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : isColRelatedToSelectedRel
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.22,
                                    )
                                  : Colors.transparent,
                              borderRadius: (isColRelatedToSelectedRel || hasFkTypeError)
                                  ? BorderRadius.circular(6)
                                  : null,
                              border: hasFkTypeError
                                  ? Border.all(
                                      color: Colors.red,
                                      width: 1.5,
                                    )
                                  : isColRelatedToSelectedRel
                                  ? Border.all(
                                      color: theme.colorScheme.primary,
                                      width: 1.5,
                                    )
                                  : Border(
                                      bottom: BorderSide(
                                        color:
                                            (isDark
                                                    ? AppColors.darkBorder
                                                    : AppColors.lightBorder)
                                                .withValues(alpha: 0.3),
                                        width: 0.5,
                                      ),
                                    ),
                              boxShadow: hasFkTypeError
                                  ? [
                                      BoxShadow(
                                        color: Colors.red.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : isColRelatedToSelectedRel
                                  ? [
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Badges de Chaves (PK / FK / UQ)
                                if (col.isPrimaryKey) ...[
                                  _buildBadge(
                                    'PK',
                                    AppColors.primaryKeyGold,
                                    Colors.black,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                if (col.isForeignKey) ...[
                                  _buildBadge(
                                    'FK',
                                    hasFkTypeError ? Colors.red : AppColors.foreignKeyCyan,
                                    Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                if (col.isUnique && !col.isPrimaryKey) ...[
                                  _buildBadge(
                                    'UQ',
                                    AppColors.uniquePurple,
                                    Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                ],

                                // Nome da Coluna
                                Expanded(
                                  child: Text(
                                    col.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: col.isPrimaryKey
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Tipo de Dado
                                Text(
                                  col.lengthOrPrecision != null &&
                                          col.lengthOrPrecision!.isNotEmpty
                                      ? '${col.dataType}(${col.lengthOrPrecision})'
                                      : col.dataType,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Ícone/Alça de Conexão (Arrastar para criar FK)
                                Tooltip(
                                  message:
                                      'Arrastar para conectar a outra tabela (FK)',
                                  child: Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerDown: (event) {
                                      setState(() {
                                        _isConnectingDrag = true;
                                        _grabOffset = null;
                                      });
                                      widget.onConnectStart?.call(
                                        col.id,
                                        event.position,
                                      );
                                    },
                                    onPointerMove: (event) {
                                      widget.onConnectUpdate?.call(
                                        event.position,
                                      );
                                    },
                                    onPointerUp: (event) {
                                      setState(() {
                                        _isConnectingDrag = false;
                                        _grabOffset = null;
                                      });
                                      widget.onConnectEnd?.call(
                                        col.id,
                                        event.position,
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Icon(
                                        Icons.link_rounded,
                                        size: 16,
                                        color: isColRelatedToSelectedRel
                                            ? theme.colorScheme.primary
                                            : col.isForeignKey
                                            ? const Color(0xFF06B6D4)
                                            : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}
