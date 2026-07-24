import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/column_model.dart';
import '../../data/models/relationship_model.dart';
import '../../data/models/table_model.dart';
import '../../state/canvas_provider.dart';

final _uuid = const Uuid();

class RelationshipDialog extends ConsumerStatefulWidget {
  final String sourceTableId;
  final String sourceColumnId;
  final String targetTableId;
  final String? initialTargetColumnId;
  final RelationshipModel? existingRelationship;

  const RelationshipDialog({
    super.key,
    required this.sourceTableId,
    required this.sourceColumnId,
    required this.targetTableId,
    this.initialTargetColumnId,
    this.existingRelationship,
  });

  @override
  ConsumerState<RelationshipDialog> createState() => _RelationshipDialogState();
}

class _RelationshipDialogState extends ConsumerState<RelationshipDialog> {
  static const String createNewFkKey = '__NEW_FK_COLUMN__';

  late String _selectedTargetColumnId;
  late CardinalityType _selectedCardinality;
  late ReferentialAction _selectedOnDelete;
  late ReferentialAction _selectedOnUpdate;

  @override
  void initState() {
    super.initState();
    final rel = widget.existingRelationship;
    _selectedTargetColumnId = rel?.targetColumnId ??
        widget.initialTargetColumnId ??
        createNewFkKey;
    _selectedCardinality = rel?.cardinality ?? CardinalityType.oneToMany;
    _selectedOnDelete = rel?.onDelete ?? ReferentialAction.noAction;
    _selectedOnUpdate = rel?.onUpdate ?? ReferentialAction.noAction;
  }

  void _onSave() {
    final canvasState = ref.read(canvasProvider);
    final canvasNotifier = ref.read(canvasProvider.notifier);

    final sourceTable = canvasState.tables.firstWhere(
      (t) => t.id == widget.sourceTableId,
      orElse: () => TableModel(id: '', name: 'Tabela', position: Offset.zero, columns: []),
    );
    final targetTable = canvasState.tables.firstWhere(
      (t) => t.id == widget.targetTableId,
      orElse: () => TableModel(id: '', name: 'Tabela', position: Offset.zero, columns: []),
    );

    final sourceCol = sourceTable.columns.firstWhere(
      (c) => c.id == widget.sourceColumnId,
      orElse: () => ColumnModel(id: widget.sourceColumnId, name: 'id', dataType: 'INT4'),
    );

    String finalTargetColumnId = _selectedTargetColumnId;

    // Se optou por criar uma nova coluna FK na tabela de destino automaticamente
    if (_selectedTargetColumnId == createNewFkKey) {
      final newColId = _uuid.v4();
      final newColName = '${sourceTable.name}_${sourceCol.name}';
      final newCol = ColumnModel(
        id: newColId,
        name: newColName,
        dataType: sourceCol.dataType,
        lengthOrPrecision: sourceCol.lengthOrPrecision,
        isForeignKey: true,
      );

      final updatedTargetCols = [...targetTable.columns, newCol];
      canvasNotifier.updateTable(targetTable.copyWith(columns: updatedTargetCols));
      finalTargetColumnId = newColId;
    }

    // Se está editando um relacionamento existente
    if (widget.existingRelationship != null) {
      final updatedRel = widget.existingRelationship!.copyWith(
        targetColumnId: finalTargetColumnId,
        cardinality: _selectedCardinality,
        onDelete: _selectedOnDelete,
        onUpdate: _selectedOnUpdate,
      );
      canvasNotifier.updateRelationship(updatedRel);
    } else {
      // Criando novo relacionamento
      final newRel = RelationshipModel(
        id: _uuid.v4(),
        sourceTableId: widget.sourceTableId,
        targetTableId: widget.targetTableId,
        sourceColumnId: widget.sourceColumnId,
        targetColumnId: finalTargetColumnId,
        cardinality: _selectedCardinality,
        onDelete: _selectedOnDelete,
        onUpdate: _selectedOnUpdate,
        name: 'fk_${sourceTable.name}_${targetTable.name}',
      );

      canvasNotifier.addRelationship(newRel);
    }

    Navigator.of(context).pop();
  }

  void _onDeleteRelationship() {
    if (widget.existingRelationship != null) {
      final canvasNotifier = ref.read(canvasProvider.notifier);
      canvasNotifier.deleteRelationship(widget.existingRelationship!.id);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final theme = Theme.of(context);

    final sourceTable = canvasState.tables.firstWhere(
      (t) => t.id == widget.sourceTableId,
      orElse: () => TableModel(id: '', name: 'Origem', position: Offset.zero, columns: []),
    );
    final targetTable = canvasState.tables.firstWhere(
      (t) => t.id == widget.targetTableId,
      orElse: () => TableModel(id: '', name: 'Destino', position: Offset.zero, columns: []),
    );

    final sourceCol = sourceTable.columns.firstWhere(
      (c) => c.id == widget.sourceColumnId,
      orElse: () => ColumnModel(id: widget.sourceColumnId, name: 'coluna', dataType: 'INT4'),
    );

    // Verificar se há incompatibilidade de tipo
    bool hasTypeMismatch = false;
    String targetType = '';
    if (_selectedTargetColumnId != createNewFkKey) {
      final targetCol = targetTable.columns.firstWhere(
        (c) => c.id == _selectedTargetColumnId,
        orElse: () => ColumnModel(id: '', name: '', dataType: ''),
      );
      if (targetCol.id.isNotEmpty && targetCol.dataType != sourceCol.dataType) {
        hasTypeMismatch = true;
        targetType = targetCol.dataType;
      }
    }

    final isEditing = widget.existingRelationship != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.alt_route_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(isEditing ? 'Editar Relacionamento (FK)' : 'Novo Relacionamento (FK)'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumo de Origem e Destino
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ORIGEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        const SizedBox(height: 2),
                        Text('${sourceTable.name}.${sourceCol.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(sourceCol.dataType, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('DESTINO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        const SizedBox(height: 2),
                        Text(targetTable.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Seleção de Coluna de Destino (Existente ou Criar Nova)
            Text('Coluna de Destino na tabela ${targetTable.name}', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                initialValue: targetTable.columns.any((c) => c.id == _selectedTargetColumnId) || _selectedTargetColumnId == createNewFkKey
                    ? _selectedTargetColumnId
                    : createNewFkKey,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: const OutlineInputBorder(),
                  enabledBorder: hasTypeMismatch
                      ? OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        )
                      : null,
                  focusedBorder: hasTypeMismatch
                      ? OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        )
                      : null,
                  errorBorder: hasTypeMismatch
                      ? OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        )
                      : null,
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: createNewFkKey,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          '+ Nova coluna',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  ...targetTable.columns.map((c) {
                    final isTypeWrong = c.dataType != sourceCol.dataType;
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${c.name} (${c.dataType})',
                              style: TextStyle(
                                fontSize: 12,
                                color: isTypeWrong ? Colors.red : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isTypeWrong)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.warning_rounded, size: 16, color: Colors.red),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedTargetColumnId = val);
                  }
                },
              ),
            ),

            // Mensagem de erro de incompatibilidade de tipo
            if (hasTypeMismatch) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tipo incompatível! Coluna FK é "$targetType" mas a coluna referenciada é "${sourceCol.dataType}". Selecione uma coluna com o mesmo tipo ou crie uma nova.',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Seleção de Cardinalidade
            Text('Cardinalidade', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CardinalityType.values.map((card) {
                final isSelected = _selectedCardinality == card;
                return ChoiceChip(
                  label: Text(card.label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  selected: isSelected,
                  selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCardinality = card);
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Ações Referenciais: ON DELETE & ON UPDATE
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ON DELETE', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<ReferentialAction>(
                        initialValue: _selectedOnDelete,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 11),
                        items: ReferentialAction.values.map((act) {
                          return DropdownMenuItem(
                            value: act,
                            child: Text(act.sqlKeyword, style: const TextStyle(fontSize: 11)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedOnDelete = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ON UPDATE', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<ReferentialAction>(
                        initialValue: _selectedOnUpdate,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 11),
                        items: ReferentialAction.values.map((act) {
                          return DropdownMenuItem(
                            value: act,
                            child: Text(act.sqlKeyword, style: const TextStyle(fontSize: 11)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedOnUpdate = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (isEditing)
          TextButton.icon(
            onPressed: _onDeleteRelationship,
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            label: const Text('Remover FK', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: hasTypeMismatch ? null : _onSave,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: Text(isEditing ? 'Salvar Alterações' : 'Criar Relacionamento'),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasTypeMismatch ? Colors.grey : theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
