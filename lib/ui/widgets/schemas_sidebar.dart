import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/project_schema_model.dart';
import '../../state/canvas_provider.dart';
import '../../state/schemas_provider.dart';

class SchemasSidebar extends ConsumerStatefulWidget {
  const SchemasSidebar({super.key});

  @override
  ConsumerState<SchemasSidebar> createState() => _SchemasSidebarState();
}

class _SchemasSidebarState extends ConsumerState<SchemasSidebar> {
  late final TextEditingController _searchController;
  String? _editingSchemaId;
  late final TextEditingController _renameController;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _renameController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  void _startEditing(ProjectSchemaModel schema) {
    setState(() {
      _editingSchemaId = schema.id;
      _renameController.text = schema.name;
    });
  }

  void _saveRename(String schemaId) {
    if (_editingSchemaId == null) return;
    final newName = _renameController.text.trim();
    if (newName.isNotEmpty) {
      ref.read(schemasProvider.notifier).renameSchema(schemaId, newName);
    }
    setState(() {
      _editingSchemaId = null;
    });
  }

  void _createNewSchema() {
    final schemasNotifier = ref.read(schemasProvider.notifier);
    final canvasNotifier = ref.read(canvasProvider.notifier);

    final count = ref.read(schemasProvider).schemas.length + 1;
    schemasNotifier.createSchema('Esquema $count');

    // Carregar canvas limpo para o novo esquema
    canvasNotifier.clearCanvas();
  }

  void _confirmDelete(ProjectSchemaModel schema) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Esquema'),
        content: Text(
          'Tem certeza que deseja excluir o esquema "${schema.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(schemasProvider.notifier).deleteSchema(schema.id);
              Navigator.of(ctx).pop();

              // Atualizar canvas com o esquema que se tornou ativo
              final activeSchema = ref.read(schemasProvider).activeSchema;
              if (activeSchema != null) {
                ref
                    .read(canvasProvider.notifier)
                    .importDdlResult(
                      activeSchema.tables,
                      activeSchema.relationships,
                    );
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _selectAndLoadSchema(ProjectSchemaModel schema) {
    final schemasNotifier = ref.read(schemasProvider.notifier);
    final canvasNotifier = ref.read(canvasProvider.notifier);

    schemasNotifier.selectSchema(schema.id);
    canvasNotifier.importDdlResult(schema.tables, schema.relationships);
  }

  @override
  Widget build(BuildContext context) {
    final schemasState = ref.watch(schemasProvider);
    final schemasNotifier = ref.read(schemasProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredList = schemasState.filteredSchemas;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _isCollapsed ? 60 : 280,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(right: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: _isCollapsed ? 60 : 280,
            child: _isCollapsed
                ? _buildCollapsedView(
                    context,
                    theme,
                    isDark,
                    schemasState,
                    filteredList,
                  )
                : _buildExpandedView(
                    context,
                    theme,
                    isDark,
                    schemasState,
                    schemasNotifier,
                    filteredList,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedView(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    SchemasState schemasState,
    List<ProjectSchemaModel> filteredList,
  ) {
    return Column(
      children: [
        // Topo com botão de expandir e novo esquema
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                tooltip: 'Expandir Menu',
                onPressed: () => setState(() => _isCollapsed = false),
              ),
              const SizedBox(height: 2),
              IconButton(
                icon: Icon(
                  Icons.add_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                tooltip: 'Novo Esquema',
                onPressed: _createNewSchema,
              ),
            ],
          ),
        ),

        // Lista Compacta de Ícones dos Esquemas
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            itemCount: filteredList.length,
            itemBuilder: (context, index) {
              final schema = filteredList[index];
              final isActive = schema.id == schemasState.activeSchemaId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Tooltip(
                  message:
                      '${schema.name}\n(${schema.tables.length} tabelas · ${schema.relationships.length} FKs)',
                  waitDuration: const Duration(milliseconds: 300),
                  child: InkWell(
                    onTap: () => _selectAndLoadSchema(schema),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primary.withValues(alpha: 0.18)
                            : (isDark
                                  ? Colors.grey.shade900
                                  : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.dividerColor.withValues(alpha: 0.5),
                          width: isActive ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          isActive
                              ? Icons.storage_rounded
                              : Icons.storage_outlined,
                          size: 20,
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedView(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    SchemasState schemasState,
    SchemasNotifier schemasNotifier,
    List<ProjectSchemaModel> filteredList,
  ) {
    return Column(
      children: [
        // Cabeçalho da Barra Lateral (Mesmo estilo do PropertySidebar)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.storage_rounded,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Esquemas',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: _createNewSchema,
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Novo', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    tooltip: 'Minimizar Menu',
                    onPressed: () => setState(() => _isCollapsed = true),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Campo de Busca por Nome do Esquema (Search)
              TextField(
                controller: _searchController,
                onChanged: (val) => schemasNotifier.setSearchQuery(val),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar esquema por nome...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            schemasNotifier.setSearchQuery('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lista de Esquemas (Ordenados por criação)
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _searchController.text.isNotEmpty
                          ? 'Nenhum esquema encontrado para "${_searchController.text}".'
                          : 'Nenhum esquema criado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final schema = filteredList[index];
                    final isActive = schema.id == schemasState.activeSchemaId;
                    final isEditingThis = _editingSchemaId == schema.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () => _selectAndLoadSchema(schema),
                        onDoubleTap: () => _startEditing(schema),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  )
                                : (isDark
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade50),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.dividerColor.withValues(alpha: 0.5),
                              width: isActive ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons.storage_rounded
                                        : Icons.storage_outlined,
                                    size: 18,
                                    color: isActive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: isEditingThis
                                        ? TextField(
                                            controller: _renameController,
                                            autofocus: true,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 4,
                                                  ),
                                              border: OutlineInputBorder(),
                                            ),
                                            onSubmitted: (_) =>
                                                _saveRename(schema.id),
                                          )
                                        : Text(
                                            schema.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isActive
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: isActive
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                  ),

                                  // Ações de Editar / Deletar
                                  if (isEditingThis)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => _saveRename(schema.id),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    )
                                  else ...[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 15,
                                      ),
                                      tooltip: 'Renomear',
                                      onPressed: () => _startEditing(schema),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 15,
                                        color: Colors.red.shade400,
                                      ),
                                      tooltip: 'Excluir',
                                      onPressed: () => _confirmDelete(schema),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${schema.tables.length} tabelas · ${schema.relationships.length} FKs',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${schema.createdAt.day.toString().padLeft(2, '0')}/${schema.createdAt.month.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
