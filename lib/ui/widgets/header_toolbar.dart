import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generators/sql_dialect.dart';
import '../../state/canvas_provider.dart';
import '../../state/theme_provider.dart';
import 'sql_import_dialog.dart';
import 'sql_preview_dialog.dart';

class HeaderToolbar extends ConsumerWidget {
  const HeaderToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);
    final canvasNotifier = ref.read(canvasProvider.notifier);
    final themeMode = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final isDark = themeMode == ThemeMode.dark;

    return Container(
      width: double.infinity,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/app_icon.png',
                      height: 32,
                      width: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.account_tree_rounded,
                        color: Color(0xFF2563EB),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'dbDiagram Desktop',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v1.0',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Seleção de SGBD
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<SqlDialect>(
                        value: canvasState.activeDialect,
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                        isDense: true,
                        onChanged: (SqlDialect? newDialect) {
                          if (newDialect != null) {
                            canvasNotifier.setDialect(newDialect);
                          }
                        },
                        items: SqlDialect.values.map((SqlDialect d) {
                          return DropdownMenuItem<SqlDialect>(
                            value: d,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storage_rounded, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  d.displayName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Botão Adicionar Tabela
                  ElevatedButton.icon(
                    onPressed: () => canvasNotifier.addTable(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nova Tabela'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Botão Novo Relacionamento
                  OutlinedButton.icon(
                    onPressed: canvasState.tables.length < 2
                        ? null
                        : () {
                            if (canvasState.isConnectingMode) {
                              canvasNotifier.cancelConnectionMode();
                            } else {
                              if (canvasState.selectedTableId != null) {
                                canvasNotifier.startConnectionMode(
                                  canvasState.selectedTableId!,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Selecione uma tabela de origem primeiro para conectar.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                    icon: Icon(
                      canvasState.isConnectingMode
                          ? Icons.close_rounded
                          : Icons.alt_route_rounded,
                      size: 18,
                    ),
                    label: Text(
                      canvasState.isConnectingMode
                          ? 'Cancelar Conexão'
                          : 'Conectar Tabelas',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: canvasState.isConnectingMode
                          ? Colors.orange
                          : null,
                      side: canvasState.isConnectingMode
                          ? const BorderSide(color: Colors.orange, width: 2)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Botão Limpar Canvas
                  IconButton(
                    tooltip: 'Limpar Canvas',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Limpar Canvas'),
                          content: const Text(
                            'Tem certeza que deseja remover todas as tabelas e conexões?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                canvasNotifier.clearCanvas();
                                Navigator.of(ctx).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text(
                                'Limpar Tudo',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 8),

                  // Toggle Dark/Light Mode
                  IconButton(
                    tooltip: isDark
                        ? 'Alternar para Light Mode'
                        : 'Alternar para Dark Mode',
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                    color: isDark ? Colors.amber : Colors.indigo,
                    onPressed: () => themeNotifier.toggleTheme(),
                  ),

                  const SizedBox(width: 12),

                  // Botão Exportar SQL DDL
                  FilledButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const SqlPreviewDialog(),
                      );
                    },
                    icon: const Icon(Icons.code_rounded, size: 18),
                    label: const Text('Gerar SQL (DDL)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Botão Importar SQL (Tom Amarelo)
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const SqlImportDialog(),
                      );
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text(
                      'Importar SQL',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
