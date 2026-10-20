# Sincronização manual

No **Perfil → Sincronizar dados**, o Nativa envia alterações deste aparelho e busca os montantes compartilhados no MongoDB. Login e sincronização usam a mesma `API_BASE_URL`. Não há atualização automática ou em segundo plano.

## Uso entre aparelhos

1. Entre com a conta de demonstração e sincronize antes de começar a editar, para consultar os dados atuais.
2. Cadastre montantes e salve os rateios, incluindo a classificação de sobras e perdas.
3. Volte ao Perfil e sincronize para enviar essas alterações.
4. No outro aparelho, sincronize para recebê-las. Início, Montantes, Produtos, relatórios e PDFs usam a cópia atualizada.

O aplicativo real inicia sem montantes de exemplo. Alimentos e escolas são catálogos definidos no código; a sincronização não transforma coleções arbitrárias do banco em novos cadastros. O perfil continua fixo para demonstração.

## Conflitos e falhas

Se o mesmo montante foi alterado localmente e no banco, a sincronização mantém a edição local e apresenta **Revisar versões**. O usuário pode manter a edição no aparelho ou escolher explicitamente **Usar versão do banco**, descartando a edição local. O app consulta novamente o banco ao confirmar. Manter a edição local não força a sobrescrita da outra versão; o conflito permanece até ser resolvido.

Durante o envio, uma janela bloqueia a interação. Uma sessão expirada retorna ao login; os rascunhos continuam no cache. Falhas de conexão permitem tentar novamente. O UUID de criação é salvo antes de enviar e o backend reconhece reenvios do mesmo conteúdo, evitando duplicações quando a resposta se perde depois da gravação.

Cada montante é validado e gravado em um documento atômico com controle de revisão. A sincronização completa não é uma transação única: alguns montantes podem ser enviados antes de ocorrer uma falha em outro. A próxima tentativa retoma a comparação. A data da última sincronização completa só avança quando não existem conflitos.

## Cache e limites do MVP

- O cache usa `shared_preferences`, separado pelo endereço da API, e é restaurado após autenticar. Não guarda senha nem token. Sair da conta não apaga a cópia de trabalho.
- É uma conveniência para rascunhos, sem garantia de durabilidade para dados críticos. Limpar os dados do app, desinstalar, limpar o armazenamento do navegador ou uma falha de disco pode perder alterações não enviadas. O MongoDB é a referência após a sincronização; backups do servidor exigem configuração operacional própria.
- Versões anteriores mantinham montantes somente em memória: esses registros não podem ser recuperados automaticamente depois que o processo foi encerrado.
- O login depende de rede e o token permanece só em memória. Restaurar cache não oferece login offline.
- Todos usam a mesma conta MVP e compartilham os mesmos registros. Não há usuários individuais, atribuição de autoria, permissões por escola ou isolamento entre associações. Um aparelho compartilhado mantém a cópia de trabalho do MVP.
- A consulta pagina até 5.000 montantes. O limite HTTP do backend é 100 requisições por minuto; operações grandes podem exigir nova tentativa.
- Alterações diretas no MongoDB devem respeitar o esquema e atualizar a revisão. Prefira a API: ela valida quantidades, pedidos, participantes e classificação do saldo. Registros inconsistentes são recusados pelo cliente.
- Remover um montante diretamente no banco gera conflito na cópia local, que só é removida após confirmação do usuário. A sincronização não oferece exclusão remota pelo app.

## Verificação isolada

Na raiz, com dependências Flutter e backend instaladas:

```sh
dart analyze
flutter test
npm run typecheck --prefix backend
npm test --prefix backend
FLUTTER_BIN="$(command -v flutter)" npm run test:integration --prefix backend
npm run build --prefix backend
```

O último conjunto inicia MongoDB temporário e API em `127.0.0.1`, usando credenciais exclusivas de teste. Dois clientes Flutter validam criação, leitura, rateio, relatórios locais, conflito, restauração do cache e repetição após perda de resposta. Não usa o Atlas nem altera registros da demonstração. `flutter test` sozinho pula o teste que depende dessa API temporária.
