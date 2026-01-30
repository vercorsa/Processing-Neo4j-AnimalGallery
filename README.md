Processing (P3D) · Neo4j · Interação 3D

Aplicação 3D desenvolvida em Processing (P3D) que simula o interior de uma loja de animais virtual, com navegação em primeira pessoa, quadros interativos e integração com uma base de dados Neo4j.
Os animais são carregados dinamicamente da base de dados e exibidos em diferentes paredes do ambiente, incluindo uma parede central de destaque, com filtros avançados e painel informativo em tempo real.

Este projeto foi inicialmente desenvolvido em contexto académico e posteriormente refinado e documentado para portfólio, com foco em organização de código, clareza arquitetural e boas práticas.
--------------------------
✨ Destaques do Projeto

Ambiente 3D totalmente navegável (FPS)

Integração com Neo4j via HTTP (Cypher + JSON)

Exposição de animais em quadros com imagem e legenda

Parede central interativa com destaque visual

Sistema de filtros dinâmicos

Painel de informação contextual (animal em foco)

Iluminação otimizada respeitando limites do Processing

Sistema de colisão (movimento apenas no chão)
-------------------------
🎮 Navegação e Controles
Movimento

W / A / S / D – mover no chão

Mouse – olhar em volta

SHIFT – correr

R – resetar posição

Filtros

1 – cães

2 – gatos

3 – vacas

0 – todos

4 – apenas com dono

5 – apenas para adoção

M / F – sexo

C – cor

P – pelagem

B – raça

L – limpar filtros
--------------------
🧱 Estrutura do Ambiente 3D

Sala com chão, teto e paredes texturizadas

Quadros distribuídos automaticamente em grade

Parede central menor (frente e verso) para destaque de animais

Sistema de colisão para evitar atravessar paredes

Movimento restrito ao plano XZ (sem voo)
-------------------
🗄️ Base de Dados (Neo4j)
Modelo de Dados

Nós

Animal

Pessoa

Relação

(Animal)-[:TEM_DONO]->(Pessoa)

Propriedades do Animal

id

nome

tipo

raça

cor

pelagem

sexo

idade

paraAdocao

img (caminho da imagem)

audio (opcional)

Os dados são carregados dinamicamente no Processing através de uma consulta Cypher enviada via HTTP para a API REST do Neo4j.
----------
🧠 Arquitetura do Código

setup()
Inicializa janela, fontes, texturas, carrega dados do Neo4j e calcula o layout inicial.

draw()
Loop principal responsável por:

atualizar câmera

aplicar colisões

desenhar sala, quadros e parede central

controlar iluminação

renderizar UI e painel de informação

AnimalItem
Classe responsável por:

armazenar dados do animal

calcular posição no mundo 3D

desenhar o quadro, imagem e legenda corretamente orientados

Sistema de Filtros
Atua sobre a lista completa de animais, gerando uma lista visível sem necessidade de nova consulta à base de dados.
-----------------------
💡 Iluminação

Luz ambiente e direcional fixa

Luz pontual aplicada apenas aos quadros mais próximos do utilizador

Número de luzes limitado para respeitar as restrições do Processing/OpenGL

🛠️ Tecnologias Utilizadas

Processing 4 (Java / P3D)

Neo4j (local, via HTTP REST)

Programação orientada a objetos

Vetores 3D (PVector)

Texturas e iluminação em OpenGL
------------------
▶️ Como Executar

Instalar o Processing 4

Instalar e iniciar o Neo4j Desktop

Criar uma base de dados local com nós Animal e Pessoa

Ajustar as credenciais no código:

String NEO4J_URL  = "http://localhost:7474/db/neo4j/tx/commit";
String NEO4J_USER = "neo4j";
String NEO4J_PASS = "password";


Garantir que os assets estão em:

data/assets/animais/
data/assets/texturas/


Executar o sketch no Processing
-------------------------
👤 Autor

Desenvolvido por João Gabriel Verçosa Ferreira
