# Escolas cadastradas

O catálogo possui 13 opções: as três entradas originais do protótipo (`IFES`, `Pinto Coelho`, `Darllin`) e dez escolas municipais públicas de Cariacica–ES adicionadas em 20/10/2026.

Os nomes e bairros das novas escolas foram conferidos na [lista oficial de EMEFs da Prefeitura Municipal de Cariacica](https://cariacica.es.gov.br/pagina/ler/376/escola-municipal-de-ensino-fundamental-emef). O cadastro no aplicativo não comprova participação na associação nem existência de pedidos.

| Escola | Bairro |
| --- | --- |
| EMEF Agustinha Muniz de Oliveira | Vila Prudêncio |
| EMEF Alice Coutinho Santos | Padre Gabriel |
| EMEF Almerinda Portela Colodette | Vila Progresso |
| EMEF Álvaro Armeloni | Oriente |
| EMEF Amenóphis de Assis | Vale Esperança |
| EMEF Angelo Zani | Mucuri |
| EMEF Antário Alexandre Theodoro Filho | São Francisco |
| EMEF Antero José do Nascimento | Vale dos Reis |
| EMEF Antonio Coutinho de Oliveira | Retiro Saudoso |
| EMEF Arthur da Costa e Silva | Aparecida |

As três entradas originais foram preservadas por compatibilidade, sem confirmação de seus nomes completos nesta inclusão. Os montantes de exemplo mantêm apenas essas três escolas. No cadastro de um novo montante, o usuário escolhe quais escolas do catálogo participarão; nenhuma nova escola é incluída automaticamente nos montantes já cadastrados com participantes definidos.

O catálogo é definido em [lib/domain/catalog.dart](../lib/domain/catalog.dart) e [backend/src/domain/catalog.ts](../backend/src/domain/catalog.ts). A API expõe a lista em `GET /v1/catalog/schools`, com autenticação. As escolas não são uma coleção MongoDB nesta versão: não foi feita inclusão nem alteração de registros reais no Atlas.
