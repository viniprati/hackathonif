# Acessibilidade para pessoas mais velhas

## Como ativar

Abra o botão **Acessibilidade** na barra superior (disponível também antes do login) ou **Perfil → Acessibilidade** e ative **Alto contraste**. A preferência é gravada no aparelho com o mesmo mecanismo de persistência do aplicativo, em uma chave própria. Se não conseguir salvar, a opção anterior continua ativa e é possível tentar novamente.

Os controles de letras continuam no topo. A ampliação de até 200% respeita o tamanho configurado no sistema e funciona junto com o alto contraste. Como antes, os passos adicionais de ampliação valem durante a sessão; esta mudança não adiciona persistência para esses passos.

## Implementação

- **Contraste:** temas centralizados, campos com contornos visíveis, texto escuro, botões e navegação com cores explícitas, estados também indicados por texto, seleção ou ícones. Testes de luminância verificam pares da paleta com razão mínima de 4,5:1 para textos e 3:1 para contornos. Gráficos mantêm legendas, números e resumos acessíveis; a pizza possui separadores.
- **Leitor de tela:** cards são anunciados como botões, títulos como cabeçalhos e dias do calendário com data completa, seleção e situação. Ícones interativos possuem rótulos; a imagem da marca não duplica seu nome. Erros importantes usam regiões de anúncio. Controles padrão preservam os estados de seleção, expansão, marcação e desabilitação.
- **Formulários:** rótulos sempre visíveis, indicação textual de obrigatoriedade, exemplos, teclados e ações adequados, campos numéricos e escolas em disposição vertical quando necessário. Formulários e diálogos permitem rolagem; o envio inválido leva o foco e a rolagem ao primeiro erro. Preenchimento automático é configurado no login.
- **Erros:** mensagens diferentes para validação, credenciais recusadas, conexão, indisponibilidade e gravação no aparelho. Valores permanecem para correção ou nova tentativa. Cadastro e rateio só apresentam sucesso após salvar a cópia local; o compartilhamento continua exigindo a sincronização pelo Perfil. As validações do domínio e do backend permanecem.
- **Ações destrutivas:** remoção de alimento do rascunho e limpeza da seleção de escolas oferecem desfazer persistente enquanto o cadastro estiver aberto. Descartar cadastro preenchido, substituir rateio finalizado e abandonar edição local em conflito exigem confirmação com item e consequência. Há bloqueios para toques repetidos. Uma falha de gravação ao usar a versão do banco restaura a edição local em memória e mantém o conflito para nova tentativa.

## Limites de reversão

A API atual não oferece exclusão lógica, restauração nem histórico de versões. Não foi implementado desfazer de dados já substituídos ou sincronizados. O desfazer do rascunho restaura os próprios dados ainda não enviados; não simula restauração do banco. Fechar um cadastro após confirmar o descarte é irreversível.

## Verificações automatizadas

```sh
flutter analyze
flutter test
flutter build web --no-wasm-dry-run
npm test --prefix backend
```

Os testes em `test/accessibility/` cobrem persistência e falha ao salvar a preferência, preservação da fonte e dos campos ao trocar o tema, contraste da paleta, diretrizes de contraste/rótulos/alvos de toque no login, foco no primeiro erro, semântica do calendário e dos cards, desfazer e descarte. Há cenários com fonte de 200%, tela estreita e teclado aberto. Testes de dados cobrem orientações de rede/servidor e preservação da edição local quando a gravação da versão remota falha.

Essas verificações não equivalem a certificação WCAG nem a teste nativo com leitor de tela. Não foi executado TalkBack ou VoiceOver: não havia dispositivo compatível conectado e o emulador Android disponível encerrou antes de iniciar.

## Roteiro manual em Android e iOS

1. Ative TalkBack/VoiceOver; percorra login, calendário, cards, Produtos, Controle de montantes, Relatórios e Perfil. Confira nomes, ordem de leitura e estados sem anúncios duplicados.
2. Ative alto contraste, feche e reabra o app. Aumente as letras no sistema e na barra; confira rolagem, diálogos, gráficos e botões sem sobreposição. Teste também na horizontal.
3. Envie login e cadastro vazios. Confira anúncio, foco no primeiro erro, teclado adequado e valores preservados após corrigir. Teste sem internet e com credenciais inválidas.
4. No cadastro de teste, preencha alimento, quantidade e preço; remova e desfaça. Limpe e desfaça escolas. Cancele o descarte e confira os valores.
5. Em dados exclusivos de teste, revise pedidos excessivos e a confirmação de sobra/perda; cancele a substituição de um rateio finalizado. Em conflito de sincronização, leia a consequência antes de confirmar.

Teste adicionalmente navegação por teclado na Web e leitores de tela nas versões dos sistemas usadas pelos participantes. O conteúdo de PDFs exportados não recebeu remediação de acessibilidade nesta mudança.
