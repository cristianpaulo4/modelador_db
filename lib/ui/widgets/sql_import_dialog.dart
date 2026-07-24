import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../parsers/sql_ddl_parser.dart';
import '../../state/canvas_provider.dart';

class SqlImportDialog extends ConsumerStatefulWidget {
  const SqlImportDialog({super.key});

  @override
  ConsumerState<SqlImportDialog> createState() => _SqlImportDialogState();
}

class _SqlImportDialogState extends ConsumerState<SqlImportDialog> {
  late final TextEditingController _sqlController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sqlController = TextEditingController();
  }

  @override
  void dispose() {
    _sqlController.dispose();
    super.dispose();
  }

  Future<void> _pickSqlFile() async {
    try {
      setState(() => _isLoading = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sql', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String content = '';
        if (file.bytes != null) {
          content = String.fromCharCodes(file.bytes!);
        } else if (file.path != null) {
          content = await File(file.path!).readAsString();
        }

        if (content.isNotEmpty) {
          setState(() {
            _sqlController.text = content;
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao ler arquivo: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onImport() {
    final text = _sqlController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, selecione um arquivo .sql ou cole o script DDL.';
      });
      return;
    }

    try {
      final parseResult = SqlDdlParser.parseSqlScript(text);

      if (parseResult.tables.isEmpty) {
        setState(() {
          _errorMessage = 'Nenhuma instrução CREATE TABLE válida encontrada no script.';
        });
        return;
      }

      final canvasNotifier = ref.read(canvasProvider.notifier);
      canvasNotifier.importDdlResult(parseResult.tables, parseResult.relationships);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importado com sucesso! ${parseResult.tables.length} tabelas e ${parseResult.relationships.length} relacionamentos gerados visualmente.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao processar o script DDL: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amberColor = Colors.amber.shade700;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: amberColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.file_upload_outlined, color: amberColor, size: 24),
          ),
          const SizedBox(width: 10),
          const Text('Importar Arquivo SQL'),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecione um arquivo .sql contendo suas instruções CREATE TABLE ou cole o código DDL abaixo para gerar os cards e relacionamentos de forma visual.',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),

              // Botão de upload de arquivo .SQL
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: amberColor,
                      side: BorderSide(color: amberColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Selecionar Arquivo .SQL', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isLoading ? null : _pickSqlFile,
                  ),
                  const SizedBox(width: 12),
                  if (_sqlController.text.isNotEmpty)
                    Text(
                      '(${_sqlController.text.split('\n').length} linhas carregadas)',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Campo de texto de código SQL DDL
              Text('Código SQL DDL (CREATE TABLE):', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _sqlController,
                maxLines: 12,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: '''CREATE TABLE usuarios (
  id INT PRIMARY KEY AUTO_INCREMENT,
  nome VARCHAR(100) NOT NULL,
  email VARCHAR(255) UNIQUE
);

CREATE TABLE pedidos (
  id INT PRIMARY KEY,
  usuario_id INT,
  valor NUMERIC(10,2),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);''',
                  hintStyle: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: amberColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.visibility_rounded, size: 18),
          label: const Text(
            'Importar e Mostrar de Forma Visual',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: _onImport,
        ),
      ],
    );
  }
}
