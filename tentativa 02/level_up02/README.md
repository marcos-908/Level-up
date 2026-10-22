# LEVEL UP — RPG da vida real

Aplicativo web responsivo com tema gamer preto/grafite/vermelho. O projeto é novo e não remove tabelas existentes do Supabase.

## O que já está implementado

- Navegação por 13 áreas, responsiva para celular.
- Tarefas com criação, edição, exclusão, prioridade, categoria, prazo e estado.
- Calendário mensal, semanal e diário com tarefas e eventos agendados.
- Perfil de jogador e progressão de nível por XP.
- XP para tarefas concedido por função PostgreSQL idempotente; outros registros usam RPC com chave única de origem.
- Exercícios de inglês de múltipla escolha com explicação após a resposta e histórico de tentativas.
- Vocabulário pessoal.
- Registro de atividades físicas e sessões de estudo.
- Hábitos com registro diário e arquivamento.
- Evolução com gráficos calculados de registros reais.
- Missões e conquistas iniciais derivadas de condições reais.
- Preferências de sons, volume, lembretes, antecedência, notificações do navegador e horário de silêncio.
- Sons sintetizados pela Web Audio API; não há arquivos de áudio externos.
- Notificações visuais centralizadas.
- Modo local opcional para experimentar sem Supabase. Ele não é autenticação e não sincroniza entre dispositivos.

## Requisitos

- VS Code.
- Extensão Live Server.
- Projeto Supabase existente.
- Chave **publicável** (`sb_publishable_...`) ou chave `anon` pública do Supabase. Nunca use `service_role`.

## Executar no VS Code

1. Extraia o ZIP.
2. Abra a pasta `level-up` no VS Code.
3. Abra `assets/js/config.js`.
4. Cole a chave pública do seu projeto em `SUPABASE_KEY`. A URL já aponta para `https://vnmipefemyewhdtbbxfy.supabase.co`.
5. No Supabase, abra **SQL Editor** e execute o conteúdo de `supabase/001_level_up.sql` uma vez. O script é aditivo e não apaga tabelas existentes.
6. No VS Code, clique com o botão direito em `index.html` e escolha **Open with Live Server**.
7. Use a URL local apresentada pelo Live Server.

> Se não configurar a chave ou o SQL, o aplicativo abre em modo local para experimentar tarefas e interface. O modo local não oferece login real nem segurança de conta.

## Supabase Auth: URLs

No painel do Supabase, entre em **Authentication → URL Configuration**:
- **Site URL:** a URL base usada no desenvolvimento, geralmente `http://127.0.0.1:5500` ou `http://localhost:5500` (use a que o Live Server realmente mostrar).
- **Redirect URLs:** adicione a URL exata do Live Server, por exemplo `http://127.0.0.1:5500/**` e/ou `http://localhost:5500/**`.
- Para produção, adicione também o domínio final e não deixe URLs de desenvolvimento em uma lista pública desnecessária.
- Em **Authentication → Providers → Email**, escolha se confirmação de e-mail fica ativa. Com confirmação ativa, o usuário precisa abrir o link enviado. O envio depende das configurações de e-mail/SMTP do Supabase; o app não pode prometer entrega por conta própria.
- Configure os templates e a URL de redirecionamento conforme sua política. A recuperação de senha usa a URL atual da página.
- Nunca cole senha do banco, `service_role` ou outros segredos neste projeto frontend.

## Banco e segurança

`supabase/001_level_up.sql` cria tabelas com prefixo `lu_`, índices, RLS e funções RPC. Todas as tabelas usam `user_id` e políticas para limitar leitura/escrita aos dados do usuário autenticado. O XP de conclusão de tarefas é concedido no servidor pela função `lu_complete_task`, com lock de linha e unicidade de `(user_id, source_type, source_id)`. A função `lu_award_activity_xp` limita tipos e valores e evita duplicação pela mesma origem.

Execute o SQL inteiro em **SQL Editor**. Se o Supabase reportar um erro, não continue supondo que o banco está pronto: corrija o erro indicado e execute novamente com cuidado. O script não contém `DROP TABLE` nem comandos de limpeza de dados antigos.

## Lembretes: o que funciona e limitações

- O app verifica prazos aproximadamente a cada 15 segundos enquanto a página está aberta.
- O navegador pode suspender timers em segundo plano. Notificações confiáveis com o navegador fechado exigem serviço de agendamento/push e infraestrutura adicional; isso **não está implementado** nesta versão.
- A preferência global permite ligar/desligar lembretes, escolher antecedência, sons e horários de silêncio.
- A chave de lembrete fica na `sessionStorage` para não repetir na mesma sessão. Alterar o prazo cria uma nova chave; concluir/excluir tira o item da consulta ativa.
- Notificações do navegador exigem permissão explícita e contexto seguro (localhost normalmente é considerado seguro). A permissão não é solicitada automaticamente.
- Nesta versão, as preferências por categoria e o adiamento individual não estão implementados; o seletor padrão aplica-se globalmente.
- Sons são gerados com Web Audio API. Alguns navegadores só permitem áudio após interação do usuário.

## XP e nível

- Tarefa concluída: +20 XP.
- Resposta correta de inglês: +5 XP.
- Sessão de estudo, atividade física: +10 XP.
- Hábito concluído: +5 XP.
- Nível = `floor(sqrt(XP / 100)) + 1`. O limite de XP por nível é progressivo; o dashboard exibe o progresso dentro do nível.
- O histórico real é calculado a partir de `lu_xp_events`. A função SQL evita duplicação pela mesma ação de origem.

## Testes e limites conhecidos

Testes estáticos e inspeção dos arquivos foram feitos durante a geração. Não foi possível autenticar em seu projeto Supabase, executar o SQL no seu painel nem testar e-mail/notificações reais a partir desta sessão. Portanto, login remoto, políticas efetivas e sincronização precisam ser validados após você executar os passos acima.

Antes de usar com dados importantes, teste:
1. Criar conta com um e-mail seu e verificar o comportamento de confirmação.
2. Entrar, criar uma tarefa, recarregar a página e conferir persistência.
3. Concluir a mesma tarefa duas vezes e confirmar que o XP não duplica.
4. Criar uma segunda conta e confirmar isolamento entre contas.
5. Conceder permissão de notificação no navegador e testar lembretes com um prazo próximo.
6. Testar em uma janela estreita/celular.

### Funcionalidades ainda parciais

- A UI tem áreas de missões/conquistas iniciais; missões diárias/semanais configuráveis e um catálogo de recompensas resgatáveis ainda não foram implementados.
- O calendário lista tarefas e eventos; não tem arrastar-e-soltar nem edição completa de eventos.
- Gráficos disponíveis nesta versão mostram XP dos últimos 7 dias e contagens reais; filtros de 30/90 dias e comparação de períodos ainda não foram implementados.
- Inglês inclui uma trilha inicial de múltipla escolha; tradução livre, associação, ordenar palavras, leitura e revisão espaçada ainda não foram implementados.
- Hábitos registram conclusão diária, mas frequência personalizada por dias da semana ainda é parcial.
- Perfil inclui nome, nível e resumo; avatar personalizado ainda não está disponível.
- Preferências por categoria e adiamento de lembretes ainda não estão disponíveis.

O objetivo desta primeira entrega é uma base funcional e coerente, com persistência e segurança do lado do banco para XP, sem fingir que os itens parciais já estão completos.
