# LEVEL UP — como rodar

1. **Banco:** Supabase > SQL Editor > cole o conteúdo de `schema.sql` e execute (uma vez). Não apaga nada; cria tabelas `lu_*`.
2. **Chave:** abra `config.js` e cole a chave "anon public" (Project Settings > API) em `SUPABASE_ANON_KEY`.
3. **Auth:** em Authentication > Providers, deixe "Email" ligado. Se a confirmação de e-mail estiver ligada, confirme o e-mail após criar a conta.
4. **VS Code:** abra a pasta `level_up`, clique com o botão direito em `index.html` > "Open with Live Server".

## Incluído
Login/cadastro/logout, Início, Tarefas (criar/editar/concluir/excluir/filtrar, XP pelo banco), Inglês (6 exercícios + histórico + meta semanal), Minha Evolução (dados reais), Configurações (sons, volume, lembretes, silêncio, perfil), lembretes com o app aberto.

## Não incluído ainda
Exercícios físicos, Estudos, Hábitos, Calendário, Missões/Conquistas, categorias de lembrete, comparação mensal.
