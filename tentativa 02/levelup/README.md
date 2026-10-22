# LEVEL UP (versão inicial funcional)

## O que já existe (real, com Supabase)
Cadastro, login, logout, recuperação de senha, sessão persistente • Início (nível, XP, barra, prazos) • Tarefas (criar, editar, excluir, concluir, prioridade, categoria, prazo, filtros, atrasadas) • XP seguro (calculado no banco, sem duplicação) • Configurações (nome, sons, lembretes) persistentes • Sons (Web Audio) • Notificações visuais • Lembretes com antecedência configurável.

## O que AINDA NÃO existe
Calendário, Inglês, Exercícios, Estudos, Hábitos, Evolução/gráficos, Missões, Conquistas, Recompensas, horários de silêncio, lembrete por categoria/tarefa, adiar lembrete. Não há itens falsos no menu para eles.

## Como rodar
1. Supabase > SQL Editor: execute `sql/01_schema.sql` (não apaga nada).
2. Supabase > Settings > API: copie a chave **anon/publishable** e cole em `js/config.js`. Nunca use `service_role`.
3. Supabase > Authentication > URL Configuration: Site URL `http://127.0.0.1:5500` e adicione em Redirect URLs `http://127.0.0.1:5500/**` (e `http://localhost:5500/**`).
4. Para testar rápido, desative "Confirm email" em Authentication > Providers > Email; com ele ativo, o e-mail de confirmação depende do envio de e-mails do Supabase.
5. VS Code: botão direito em `index.html` > Open with Live Server.

## Limitações
Lembretes só disparam com a página aberta; notificação do navegador exige permissão. Precisa de internet (Supabase e fontes via CDN).
## XP e nível
XP por tarefa: baixa 10, média 20, alta 30. Nível = floor(√(XP/100)) + 1. XP e nível não podem ser editados pelo cliente (revogado no banco).
## Testes
Nenhum teste foi executado: o ambiente não tem acesso à internet/Supabase. Revisão manual do código apenas.
