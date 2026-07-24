import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/project_schema_model.dart';

final _uuid = const Uuid();

class SchemasState {
  final List<ProjectSchemaModel> schemas;
  final String? activeSchemaId;
  final String searchQuery;

  const SchemasState({
    this.schemas = const [],
    this.activeSchemaId,
    this.searchQuery = '',
  });

  SchemasState copyWith({
    List<ProjectSchemaModel>? schemas,
    String? activeSchemaId,
    String? searchQuery,
  }) {
    return SchemasState(
      schemas: schemas ?? this.schemas,
      activeSchemaId: activeSchemaId ?? this.activeSchemaId,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  ProjectSchemaModel? get activeSchema {
    if (activeSchemaId == null) return null;
    return schemas.firstWhere(
      (s) => s.id == activeSchemaId,
      orElse: () => schemas.first,
    );
  }

  List<ProjectSchemaModel> get filteredSchemas {
    final sorted = List<ProjectSchemaModel>.from(schemas)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Ordem de criação

    if (searchQuery.trim().isEmpty) {
      return sorted;
    }

    final query = searchQuery.toLowerCase().trim();
    return sorted.where((s) => s.name.toLowerCase().contains(query)).toList();
  }
}

class SchemasNotifier extends StateNotifier<SchemasState> {
  SchemasNotifier() : super(const SchemasState()) {
    _loadFromDisk();
  }

  File? _getStorageFile() {
    try {
      final dir = Directory.systemTemp;
      return File('${dir.path}/modelador_db_schemas.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = _getStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final Map<String, dynamic> jsonData = jsonDecode(content);
          final schemasList = jsonData['schemas'] as List<dynamic>?;
          final savedActiveId = jsonData['activeSchemaId'] as String?;

          if (schemasList != null && schemasList.isNotEmpty) {
            final loaded = schemasList
                .map((item) => ProjectSchemaModel.fromJson(item as Map<String, dynamic>))
                .toList();

            // Restaurar o último esquema selecionado, ou usar o primeiro
            String activeId = loaded.first.id;
            if (savedActiveId != null &&
                loaded.any((s) => s.id == savedActiveId)) {
              activeId = savedActiveId;
            }

            state = state.copyWith(
              schemas: loaded,
              activeSchemaId: activeId,
            );
            return;
          }
        }
      }
    } catch (_) {}

    // Se não houver arquivo salvo, cria um Esquema Padrão Inicial
    final defaultSchema = ProjectSchemaModel(
      id: _uuid.v4(),
      name: 'Esquema Principal',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      schemas: [defaultSchema],
      activeSchemaId: defaultSchema.id,
    );

    _saveToDisk();
  }

  Future<void> _saveToDisk() async {
    try {
      final file = _getStorageFile();
      if (file != null) {
        final jsonData = {
          'schemas': state.schemas.map((s) => s.toJson()).toList(),
          'activeSchemaId': state.activeSchemaId,
        };
        await file.writeAsString(jsonEncode(jsonData));
      }
    } catch (_) {}
  }

  ProjectSchemaModel createSchema(String name) {
    final now = DateTime.now();
    final newSchema = ProjectSchemaModel(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Novo Esquema' : name.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final updatedList = [...state.schemas, newSchema];
    state = state.copyWith(
      schemas: updatedList,
      activeSchemaId: newSchema.id,
    );

    _saveToDisk();
    return newSchema;
  }

  void updateActiveSchemaData(ProjectSchemaModel updatedSchema) {
    final updatedList = state.schemas.map((s) {
      if (s.id == updatedSchema.id) {
        return updatedSchema.copyWith(updatedAt: DateTime.now());
      }
      return s;
    }).toList();

    state = state.copyWith(schemas: updatedList);
    _saveToDisk();
  }

  void renameSchema(String schemaId, String newName) {
    if (newName.trim().isEmpty) return;

    final updatedList = state.schemas.map((s) {
      if (s.id == schemaId) {
        return s.copyWith(
          name: newName.trim(),
          updatedAt: DateTime.now(),
        );
      }
      return s;
    }).toList();

    state = state.copyWith(schemas: updatedList);
    _saveToDisk();
  }

  void deleteSchema(String schemaId) {
    final updatedList = state.schemas.where((s) => s.id != schemaId).toList();
    String? nextActiveId = state.activeSchemaId;

    if (nextActiveId == schemaId) {
      nextActiveId = updatedList.isNotEmpty ? updatedList.first.id : null;
    }

    // Se deletou o último, cria um novo em branco automaticamente
    if (updatedList.isEmpty) {
      final fresh = ProjectSchemaModel(
        id: _uuid.v4(),
        name: 'Esquema Principal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      updatedList.add(fresh);
      nextActiveId = fresh.id;
    }

    state = state.copyWith(
      schemas: updatedList,
      activeSchemaId: nextActiveId,
    );

    _saveToDisk();
  }

  void selectSchema(String schemaId) {
    state = state.copyWith(activeSchemaId: schemaId);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final schemasProvider =
    StateNotifierProvider<SchemasNotifier, SchemasState>((ref) {
  return SchemasNotifier();
});
