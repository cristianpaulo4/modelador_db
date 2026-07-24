import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/column_model.dart';
import '../../data/models/table_model.dart';
import '../../generators/sql_dialect_generator.dart';
import '../../state/canvas_provider.dart';
import '../../state/canvas_state.dart';
import '../../state/schemas_provider.dart';

class SqlPreviewDialog extends ConsumerWidget {
  const SqlPreviewDialog({super.key});

  /// Verifica se há incompatibilidade de tipo nas FKs
  List<String> _findFkTypeErrors(CanvasState canvasState) {
    final errors = <String>[];

    for (final rel in canvasState.relationships) {
      final refTable = canvasState.tables.firstWhere(
        (t) => t.id == rel.sourceTableId,
        orElse: () => TableModel(id: '', name: '', position: Offset.zero, columns: []),
      );
      final fkTable = canvasState.tables.firstWhere(
        (t) => t.id == rel.targetTableId,
        orElse: () => TableModel(id: '', name: '', position: Offset.zero, columns: []),
      );

      if (refTable.id.isEmpty || fkTable.id.isEmpty) continue;

      final refCol = refTable.columns.firstWhere(
        (c) => c.id == rel.sourceColumnId,
        orElse: () => ColumnModel(id: '', name: '', dataType: ''),
      );
      final fkCol = fkTable.columns.firstWhere(
        (c) => c.id == rel.targetColumnId,
        orElse: () => ColumnModel(id: '', name: '', dataType: ''),
      );

      if (refCol.id.isEmpty || fkCol.id.isEmpty) continue;

      if (refCol.dataType != fkCol.dataType) {
        errors.add(
          '${fkTable.name}.${fkCol.name} (${fkCol.dataType}) → ${refTable.name}.${refCol.name} (${refCol.dataType})',
        );
      }
    }

    return errors;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);
    final generator = SqlDialectGenerator.forDialect(canvasState.activeDialect);
    final ddlScript = generator.generateDdl(
      canvasState.tables,
      canvasState.relationships,
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Verificar erros de tipo nas FKs
    final fkErrors = _findFkTypeErrors(canvasState);
    final hasErrors = fkErrors.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 700,
        height: 550,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              children: [
                Icon(
                  hasErrors ? Icons.error_outline_rounded : Icons.code_rounded,
                  color: hasErrors ? Colors.red : const Color(0xFF10B981),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Script DDL SQL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Dialeto: ${canvasState.activeDialect.displayName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            // Alerta de Erros
            if (hasErrors) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Erros de Incompatibilidade de Tipo',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...fkErrors.map((error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $error',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    )),
                    const SizedBox(height: 8),
                    const Text(
                      'Corrija os tipos das colunas FK antes de exportar.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Code Preview Box
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasErrors ? Colors.red.withValues(alpha: 0.5) : theme.dividerColor,
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    ddlScript,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: hasErrors
                          ? Colors.red.withValues(alpha: 0.7)
                          : const Color(0xFF38BDF8),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bottom Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: hasErrors
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: ddlScript));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Script DDL copiado para a área de transferência!',
                              ),
                              duration: Duration(seconds: 2),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar DDL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasErrors ? Colors.grey : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: hasErrors
                      ? null
                      : () async {
                          final activeSchema = ref.read(schemasProvider).activeSchema;
                          final rawName = activeSchema?.name ?? 'esquema';
                          final sanitized = rawName
                              .toLowerCase()
                              .replaceAll(RegExp(r'\s+'), '_')
                              .replaceAll(RegExp(r'[^a-z0-9_]'), '');
                          final defaultFileName = sanitized.isEmpty
                              ? 'esquema.sql'
                              : '$sanitized.sql';

                          final String? outputFile = await FilePicker.platform
                              .saveFile(
                            dialogTitle: 'Exportar Esquema SQL',
                            fileName: defaultFileName,
                            type: FileType.custom,
                            allowedExtensions: ['sql'],
                          );

                          if (outputFile != null) {
                            final file = File(outputFile);
                            await file.writeAsString(ddlScript);

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Esquema exportado com sucesso para $defaultFileName!',
                                  ),
                                  backgroundColor: Colors.amber.shade700,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Exportar .SQL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasErrors ? Colors.grey : Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
