import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generators/sql_dialect_generator.dart';
import '../../state/canvas_provider.dart';
import '../../state/schemas_provider.dart';

class SqlPreviewDialog extends ConsumerWidget {
  const SqlPreviewDialog({super.key});

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
                const Icon(
                  Icons.code_rounded,
                  color: Color(0xFF10B981),
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
                  border: Border.all(color: theme.dividerColor),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    ddlScript,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFF38BDF8),
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
                  onPressed: () {
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
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
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
                    backgroundColor: Colors.amber.shade700,
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
