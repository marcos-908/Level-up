# LEVEL UP — instalação local

Projeto web em HTML, CSS e JavaScript ES modules, com Supabase Auth e PostgreSQL. Não usa backend próprio, Brevo, pgAdmin ou banco local.

## Antes de começar
- Um projeto Supabase existente (este projeto está configurado para `https://vnmipefemyewhdtbbxfy.supabase.co`).
- Sua chave **publicável** (`sb_publishable_...`) ou chave pública `anon` legada. Não use `service_role`.
- VS Code e extensão Live Server.

## 1. Configure a chave pública
1. Abra `config.js` no VS Code.
2. Cole sua chave publicável em `SUPABASE_PUBLISHABLE_KEY`, substituindo `COLE_SUA_CHAVE_PUBLICAVEL_AQUI`.
3. A URL-base já está preenchida. Não use a URL `/rest/v1/` como URL do cliente.
4. Salve. A chave pública é apropriada para frontend **somente com RLS habilitado e políticas corretas**.

## 2. Configure o banco sem apagar dados antigos
1. Entre no painel do projeto Supabase correto.
2. Abra **SQL Editor → New query**.
3. Abra `sql/01_schema.sql`, copie todo o conteúdo e execute.
4. O script é aditivo e usa `CREATE TABLE IF NOT EXISTS`; não remove tabelas antigas. Ele cria tabelas com prefixo `lu_`, políticas RLS e a função transacional de conclusão. As políticas `DROP POLICY IF EXISTS` removem/recriam apenas políticas com estes nomes específicos nas tabelas `lu_`.
5. Se o projeto tiver tabelas `lu_` preexistentes com estrutura diferente, pare antes de executar e faça backup/revise a estrutura: `IF NOT EXISTS` não altera colunas incompatíveis.

Não é necessário PostgreSQL local nem pgAdmin 4.

## 3. Configure Auth no Supabase
1. No painel, abra **Authentication → URL Configuration**.
2. Em **Site URL**, durante desenvolvimento, use `http://127.0.0.1:5500`.
3. Em **Redirect URLs**, adicione `http://127.0.0.1:5500/**` e, se usar `localhost`, `http://localhost:5500/**`.
4. Abra **Authentication → Providers → Email** e confira se a confirmação de e-mail está ativada.
   - Se estiver ativada, o usuário precisa confirmar o endereço antes de obter uma sessão autenticada. O Supabase precisa conseguir enviar o e-mail; a entrega depende da configuração e dos limites do serviço de e-mail disponível no projeto.
   - Se estiver desativada, o cadastro pode retornar uma sessão imediatamente.
   - Este projeto não configura SMTP nem garante entrega de e-mail. A recuperação de senha chama o fluxo oficial do Supabase e informa apenas que a solicitação foi aceita pela API; a entrega depende do provedor configurado.
5. Para redefinição de senha, o link volta à página local. Depois de abrir o link, o site mostra um formulário para definir e confirmar a nova senha; a alteração é feita com `updateUser({ password })` no Supabase.

## 4. Execute com Live Server
1. Extraia a pasta `level_up` e abra essa pasta no VS Code (**File → Open Folder**).
2. Instale a extensão **Live Server** se ainda não tiver.
3. Clique com o botão direito em `index.html` → **Open with Live Server**.
4. O endereço esperado costuma ser `http://127.0.0.1:5500/index.html` (não precisa manter a pasta antiga `level_up14`). Se o Live Server escolher outra porta, use o endereço mostrado no navegador e adicione-o às Redirect URLs do Supabase.
5. Se a página disser “Configure a chave”, confirme que salvou `config.js` e recarregue.

## 5. Como testar
1. Cadastre uma conta de teste com e-mail válido e senha de 8 ou mais caracteres.
2. Se a confirmação estiver ligada, confirme o e-mail e entre.
3. Crie uma tarefa, conclua-a e confirme que o XP aumentou em 50.
4. Tente clicar novamente: uma tarefa concluída não deve pagar XP novamente.
5. Recarregue a página e confira se perfil, tarefas e XP continuam presentes.
6. Teste filtros, edição, exclusão de tarefa pendente, som ligado/desligado e volume.
7. Teste a saída e entre novamente. Use duas contas de teste para conferir o isolamento dos dados.
8. Teste recuperação de senha somente depois de configurar o e-mail do Supabase.

## Regras de XP e nível
- Cada tarefa concluída concede **50 XP** pelo RPC `lu_complete_task`.
- O JavaScript não envia o valor da recompensa: a função do banco define o XP, grava um evento único por tarefa e atualiza tarefa/perfil na mesma transação.
- Nível 1 requer 100 XP, nível 2 requer mais 200 XP, nível 3 mais 300 XP etc. XP total é a fonte persistente; o nível é calculado na interface.

## Sons e notificações
- Os efeitos são sintetizados localmente com Web Audio API; não dependem de arquivos ou URLs de áudio externos.
- O navegador exige uma interação do usuário antes de liberar áudio. Clique na página ou em um botão para desbloquear os efeitos.
- Ativação e volume ficam salvos no navegador. As preferências também são enviadas ao perfil quando você usa “Salvar preferências” com sessão ativa.
- Notificações são centralizadas em `js/notifications.js`, com fechamento manual e desaparecimento automático.

## Segurança e limites conhecidos
- Senhas são gerenciadas apenas pelo Supabase Auth; não existe tabela de senhas.
- Tabelas `lu_profiles`, `lu_tasks` e `lu_reward_events` usam RLS; o cliente só pode inserir/alterar campos permitidos do perfil, não `total_xp`. O RPC verifica usuário autenticado, propriedade da tarefa e perfil; um evento único impede XP duplicado.
- Não coloque chave `service_role` no frontend.
- As conquistas mostradas atualmente são calculadas a partir das tarefas e do nível, não são um sistema de recompensas persistido separado. Há estatísticas básicas, tarefas e preferências; hábitos, inventário e rastreamento detalhado de estudo ainda não estão implementados.
- A recuperação de senha usa o fluxo oficial do Supabase e inclui formulário para definir a nova senha após abrir o link de recuperação.
- Nenhum teste contra o seu projeto Supabase remoto foi executado neste ambiente. É necessário inserir a chave e executar o SQL para validar o fluxo real.

## Arquivos
- `index.html`: interface e formulários.
- `config.js`: URL e chave publicável.
- `css/styles.css`: identidade visual responsiva.
- `js/supabase.js`: cliente Supabase centralizado.
- `js/auth.js`: cadastro, login, logout e solicitação de recuperação.
- `js/app.js`: dashboard, perfil, tarefas, XP, configurações.
- `js/audio.js`: efeitos sintetizados e volume.
- `js/notifications.js`: notificações e tradução de erros comuns.
- `sql/01_schema.sql`: esquema, RLS, trigger de perfil e RPC de recompensa.

## Estado da recuperação
Consulte `STATUS_DA_RECUPERACAO.md` para ver as correções desta etapa, as verificações estáticas executadas, os testes que não puderam ser confirmados e as funcionalidades ainda pendentes. Não considere o login remoto validado até testar com o projeto Supabase e uma conta de teste.
