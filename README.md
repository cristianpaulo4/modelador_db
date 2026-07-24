# 🗄️ dbDiagram Desktop — Modelador Visual de Banco de Dados

Um aplicativo Desktop moderno, veloz e elegante desenvolvido em **Flutter** para modelagem de bancos de dados relacionais (Diagrama de Entidade-Relacionamento — DER). Permite criar, arrastar, conectar e editar tabelas visualmente, importar scripts `.sql` existentes e exportar código DDL para **PostgreSQL**, **MySQL**, **SQLite**, **SQL Server** e **Oracle**.

---

## 🌟 Principais Recursos

### 🎨 1. Canvas Interativo com Zoom e Pan
- **Mesa Infinita (4000x4000px)**: Navegação suave com controle de escala de **0.2x a 3.0x**.
- **Barra Flutuante de Zoom**: Botões para Aumentar Zoom (`+`), Diminuir Zoom (`-`), Resetar 100% e Centralizar Diagrama (*Fit View*).
- **Arraste Preciso de Cards**: Arraste tabelas com bloqueio matricial de ponteiro (*pointer-locked drag*), sem saltos de posição.

### 📝 2. Edição Inline Direta nos Cards
- **Nome da Tabela**: Dê um **clique** no cabeçalho do card para editar o nome da tabela diretamente.
- **Colunas e Tipos**: Dê um **clique** em qualquer linha de coluna para alterar instantaneamente o nome, tipo de dado (ex: `VARCHAR`, `INT`, `NUMERIC`) e tamanho/precisão (ex: `255`, `10,2`).
- **Badges Visuais**: Identificação de `PK` (Chave Primária), `FK` (Chave Estrangeira), `UQ` (Único), `NN` (Not Null) e `AUTO_INCREMENT`.

### 🔗 3. Criação e Gestão Interativa de Chaves Estrangeiras (FK)
- **Arraste de Conexão entre Colunas**: Clique no ícone de link `🔗` de uma coluna na **Tabela A** e arraste a linha amarela dinâmica até a **Tabela B**.
- **Tabela Imóvel no Arraste**: Durante a conexão, o card da tabela permanece 100% estático, movendo apenas a linha de conexão.
- **Diálogo Modal de Relacionamento (`RelationshipDialog`)**:
  - Selecione a coluna de destino existente ou crie automaticamente uma nova coluna FK.
  - Configure a **Cardinalidade**: `1:1`, `1:N`, `N:1`, `N:M`.
  - Defina regras referenciais de integridade: `ON DELETE` e `ON UPDATE` (`CASCADE`, `SET NULL`, `RESTRICT`, `NO ACTION`).
  - Edite ou remova relacionamentos a qualquer momento.

### 🎯 4. Renderização de Linhas Ortogonais e Destaque Visual
- **Linhas Ortogonais (90° com Cantos Arredondados)**: Conexões desenhadas de forma limpa e organizada.
- **Sobreposição Z-Index da Linha Selecionada**: A linha selecionada é desenhada sempre **no topo das demais**, com maior espessura (3.5px) e camada externa de brilho.
- **Destaque nos Cards Conectados**: Ao selecionar um relacionamento, as colunas envolvidas na Tabela A e Tabela B acendem automaticamente com fundo primário, bordas de realce e sombras luminosas.
- **Duplo Clique na Linha**: Clique duplo em qualquer segmento da linha ou nos badges `1` / `N` para abrir o modal de edição/exclusão.

### 📥 5. Importador de Arquivos SQL DDL (Botão Amarelo)
- **Importação de Arquivos `.sql`**: Selecione arquivos `.sql` / `.txt` ou cole scripts DDL `CREATE TABLE` / `ALTER TABLE`.
- **Parsing Automático (`SqlDdlParser`)**:
  - Reconhece FKs inline (`REFERENCES`), restrições de tabela (`FOREIGN KEY`) e instruções `ALTER TABLE`.
  - Processa schemas, tipos de dados, tamanhos, valores padrão, PKs, FKs, UQs e auto-incremento.
  - Organiza automaticamente as tabelas importadas em uma grade ordenada no canvas.

### 📤 6. Gerador e Exportador SQL Multi-SGBD (Botão Verde)
- Gera DDL completo com apenas 1 clique para 5 dialetos principais:
  - 🐘 **PostgreSQL**
  - 🐬 **MySQL**
  - 🪶 **SQLite**
  - 🟦 **SQL Server (T-SQL)**
  - 🧅 **Oracle**
- Modal com pré-visualização de código formatado e cópia rápida para a área de transferência.

---

## 🛠️ Tecnologias Utilizadas

- **Linguagem & Framework**: Dart ^3.12, Flutter (Windows / Desktop / Web)
- **Gerenciamento de Estado**: `flutter_riverpod` ^2.5.1
- **Gerador de IDs Únicos**: `uuid` ^4.3.3
- **Upload de Arquivos**: `file_picker` ^8.0.0
- **Tipografia**: `google_fonts` (Inter / Outfit / Roboto)
- **Renderização Gráfica**: `CustomPainter` com geometrias ortogonais e curvas quadráticas de Bézier.

---

## 📂 Estrutura do Projeto

```
lib/
├── core/
│   ├── theme/               # Paletas de cores (Dark/Light) e AppTheme
│   └── utils/               # GeometryUtils para ancoragem e caminhos ortogonais
├── data/
│   └── models/              # ColumnModel, TableModel, RelationshipModel
├── generators/
│   ├── sql_dialect.dart     # Enum dos SGBDs suportados
│   └── sql_dialect_generator.dart # Geradores de DDL DDL (Postgres, MySQL, SQLite, etc.)
├── parsers/
│   └── sql_ddl_parser.dart  # Parser DDL para leitura de arquivos .sql
├── state/
│   ├── canvas_provider.dart # Estado global Riverpod (Tabelas, Conexões, Seleção)
│   ├── canvas_state.dart    # Modelo imutável do estado do canvas
│   └── theme_provider.dart  # Estado de tema (Light / Dark)
├── ui/
│   ├── painters/            # CustomPainters (Ortogonal, Arraste, Grade)
│   ├── screens/             # MainDesignerScreen (Tela principal do designer)
│   └── widgets/             # TableCardWidget, RelationshipDialog, SqlImportDialog, etc.
└── main.dart                # Ponto de entrada do aplicativo
```

---

## 🚀 Como Executar o Projeto

### Pré-requisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado (^3.12.2 ou superior).
- Suporte para compilação Windows ou Web habilitado no Flutter.

### Passo a Passo

1. **Clonar o Repositório**:
   ```bash
   git clone https://github.com/usuario/modelador_db.git
   cd modelador_db
   ```

2. **Instalar Dependências**:
   ```bash
   flutter pub get
   ```

3. **Executar a Aplicação**:
   ```bash
   flutter run -d windows
   ```

4. **Executar Testes Unitários**:
   ```bash
   flutter test
   ```

5. **Gerar Executável de Produção (Windows Release)**:
   ```bash
   flutter build windows
   ```
   O arquivo `.exe` será gerado em: `build\windows\x64\runner\Release\modelador_db.exe`.

---

## 🧪 Testes de Qualidade

O projeto conta com uma suíte de testes unitários cobrindo:
- Geradores de SQL DDL para os 5 dialetos suportados.
- Parser DDL de scripts `.sql` (FKs inline, de tabela e via `ALTER TABLE`).
- Inicialização e ciclo de vida de widgets do aplicativo.

---

## 📄 Licença

Este projeto é desenvolvido para fins de modelagem rápida de bancos de dados relacionais. Livre para uso e modificações.
