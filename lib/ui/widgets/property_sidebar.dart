import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/column_model.dart';
import '../../data/models/relationship_model.dart';
import '../../data/models/table_model.dart';
import '../../generators/sql_dialect.dart';
import '../../state/canvas_provider.dart';
import 'relationship_dialog.dart';

class PropertySidebar extends ConsumerWidget {
  const PropertySidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final theme = Theme.of(context);

    final selectedTable = canvasState.selectedTable;
    final selectedRelationship = canvasState.selectedRelationship;

    if (selectedTable == null && selectedRelationship == null) {
      return Container(
        width: 320,
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(left: BorderSide(color: theme.dividerColor)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Painel de Propriedades',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Clique em uma tabela ou conexão no canvas para visualizar e editar seus atributos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header do Painel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(
                  selectedTable != null ? Icons.edit_note_rounded : Icons.hub_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  selectedTable != null ? 'Propriedades da Tabela' : 'Propriedades da Conexão',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    canvasNotifier.selectTable(null);
                    canvasNotifier.selectRelationship(null);
                  },
                ),
              ],
            ),
          ),

          // Conteúdo do Painel (Tabela ou Relacionamento)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: selectedTable != null
                  ? _buildTableProperties(context, ref, selectedTable, canvasState.activeDialect)
                  : _buildRelationshipProperties(context, ref, selectedRelationship!, canvasState.tables),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableProperties(
    BuildContext context,
    WidgetRef ref,
    TableModel table,
    SqlDialect activeDialect,
  ) {
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Edição de Nome e Schema
        Text('Nome da Tabela', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: table.name,
          decoration: const InputDecoration(hintText: 'Ex: usuarios'),
          onChanged: (val) {
            canvasNotifier.updateTable(table.copyWith(name: val));
          },
        ),
        const SizedBox(height: 12),

        Text('Schema', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: table.schema,
          decoration: const InputDecoration(hintText: 'Ex: public / dbo'),
          onChanged: (val) {
            canvasNotifier.updateTable(table.copyWith(schema: val));
          },
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Colunas (${table.columns.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => canvasNotifier.addColumn(table.id),
              tooltip: 'Adicionar Coluna',
            ),
          ],
        ),
        const Divider(height: 24),

        // Lista de Colunas
        ...table.columns.map((col) => _buildColumnEditor(context, ref, table.id, col, activeDialect)),

        const SizedBox(height: 24),

        // Botão Excluir Tabela
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Excluir Tabela'),
            onPressed: () => canvasNotifier.deleteTable(table.id),
          ),
        ),
      ],
    );
  }

  Widget _buildColumnEditor(
    BuildContext context,
    WidgetRef ref,
    String tableId,
    ColumnModel col,
    SqlDialect activeDialect,
  ) {
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF252830) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: col.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    hintText: 'Nome da coluna',
                  ),
                  onChanged: (val) {
                    canvasNotifier.updateColumn(tableId, col.copyWith(name: val));
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                onPressed: () => canvasNotifier.deleteColumn(tableId, col.id),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Seletor de Tipo de Dado
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: activeDialect.availableDataTypes.contains(col.dataType)
                      ? col.dataType
                      : activeDialect.availableDataTypes.first,
                  isDense: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (newType) {
                    if (newType != null) {
                      canvasNotifier.updateColumn(tableId, col.copyWith(dataType: newType));
                    }
                  },
                  items: activeDialect.availableDataTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: col.lengthOrPrecision ?? '',
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    hintText: 'Tam/Prec',
                  ),
                  onChanged: (val) {
                    canvasNotifier.updateColumn(tableId, col.copyWith(lengthOrPrecision: val));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Checkboxes de Constraints (PK, FK, NN, UQ, AI)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildConstraintCheck('PK', col.isPrimaryKey, (v) {
                canvasNotifier.updateColumn(tableId, col.copyWith(isPrimaryKey: v));
              }),
              _buildConstraintCheck('FK', col.isForeignKey, (v) {
                canvasNotifier.updateColumn(tableId, col.copyWith(isForeignKey: v));
              }),
              _buildConstraintCheck('NN', col.isNotNull, (v) {
                canvasNotifier.updateColumn(tableId, col.copyWith(isNotNull: v));
              }),
              _buildConstraintCheck('UQ', col.isUnique, (v) {
                canvasNotifier.updateColumn(tableId, col.copyWith(isUnique: v));
              }),
              _buildConstraintCheck('AI', col.isAutoIncrement, (v) {
                canvasNotifier.updateColumn(tableId, col.copyWith(isAutoIncrement: v));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConstraintCheck(String label, bool value, Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: value ? const Color(0xFF2563EB) : Colors.grey,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: value ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildRelationshipProperties(
    BuildContext context,
    WidgetRef ref,
    RelationshipModel rel,
    List<TableModel> tables,
  ) {
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final theme = Theme.of(context);

    final sourceTable = tables.firstWhere((t) => t.id == rel.sourceTableId, orElse: () => TableModel(id: '', name: 'Desconhecida', position: Offset.zero, columns: []));
    final targetTable = tables.firstWhere((t) => t.id == rel.targetTableId, orElse: () => TableModel(id: '', name: 'Desconhecida', position: Offset.zero, columns: []));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${sourceTable.name}  ➔  ${targetTable.name}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        Text('Cardinalidade', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        DropdownButtonFormField<CardinalityType>(
          initialValue: rel.cardinality,
          decoration: const InputDecoration(contentPadding: EdgeInsets.all(10)),
          items: CardinalityType.values.map((c) {
            return DropdownMenuItem(
              value: c,
              child: Text(c.label),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              canvasNotifier.updateRelationship(rel.copyWith(cardinality: val));
            }
          },
        ),
        const SizedBox(height: 16),

        Text('Regra ON DELETE', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        DropdownButtonFormField<ReferentialAction>(
          initialValue: rel.onDelete,
          decoration: const InputDecoration(contentPadding: EdgeInsets.all(10)),
          items: ReferentialAction.values.map((act) {
            return DropdownMenuItem(
              value: act,
              child: Text(act.sqlKeyword),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              canvasNotifier.updateRelationship(rel.copyWith(onDelete: val));
            }
          },
        ),
        const SizedBox(height: 16),

        Text('Regra ON UPDATE', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        DropdownButtonFormField<ReferentialAction>(
          initialValue: rel.onUpdate,
          decoration: const InputDecoration(contentPadding: EdgeInsets.all(10)),
          items: ReferentialAction.values.map((act) {
            return DropdownMenuItem(
              value: act,
              child: Text(act.sqlKeyword),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              canvasNotifier.updateRelationship(rel.copyWith(onUpdate: val));
            }
          },
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Abrir Diálogo de Configuração (FK)'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => RelationshipDialog(
                  sourceTableId: rel.sourceTableId,
                  sourceColumnId: rel.sourceColumnId,
                  targetTableId: rel.targetTableId,
                  initialTargetColumnId: rel.targetColumnId,
                  existingRelationship: rel,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Remover Conexão'),
            onPressed: () => canvasNotifier.deleteRelationship(rel.id),
          ),
        ),
      ],
    );
  }
}
