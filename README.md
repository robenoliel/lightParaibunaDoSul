# Simulador Sistema Hidráulico da Paraíba do Sul

## Introdução

Este projeto tem como desenvolver um simulador da operação do Sistema Hidráulico da Paraíba do Sul fiel a regularmentações e restrições especiais definidas pela Agência Nacional de Águas **(to do: adicionar ref a resoluções)**, que comunmente não podem ser modeladas propriamente em programas mais gerais. A aplicação desse simulador permitirá experimentação e validação com respeito a possíveis novas políticas e estratégias de despacho que visem otimizar este sistema específico.

## Identificação de plantas

O Sistema Hidráulico da Paraíba do Sul e suas periferias possuem usinas de interesse bem definidas. Neste simulador, as usinas consideradas serão constantemente identificadas por uma `String` particular, que deverão ser respeitadas a todo momento como código de identificação. Tais usinas e seus respectivos códigos são:
* Fontes A: `fontes_a`
* Fontes BC: `fontes_bc`
* Funil: `funil`
* Ilha dos Pombos: `ilha_dos_pombos`
* Jaguari: `jaguari`
* Lajes: `lajes`
* Nilo Peçanha: `nilo_pecanha`
* Paraibuna: `paraibuna`
* Pereira Passos: `pereira_passos`
* Picada: `picada`
* Santana: `santana`
* Simplício: `simplicio`
* Sobragi: `sobragi`
* Santa Branca: `sta_branca`
* Santa Cecília: `sta_cecilia`
* Tocos: `tocos`
* Vigário: `vigario`

**O simulador foi programado sob uma modelagem que considera as usinas acima, e as usinas acima somente. Ausência de dados de entrada referente a qualquer uma delas, ou uso incorreto dos indentificadores, poderá acarretar no não funcionamento do simulador, a menos que seja especificado o contrário.**

## Arquivos e diretórios

O simulador foi desenvolvido utilizando como referência projetos do mesmo sistema modelados em dois programas independentes: SUISHI e SDDP. Os arquivos de tais projetos podem ser encontrados respectivamente nas pastas `SUISHI` e `1_PMO_Agosto_ONS_Paraiba_Sul_suishi_2017`. O simulador, apesar de usar seus dados como base, não utiliza diretamente os arquivos destas pastas, eles foram incluídos somente com fins de referência.

Em seguida, serão explicadas pastas que contém dados que são utilizados como entrada para o simulador e seus respectivos conteúdos. **Enfatiza-se a importância de que arquivos CSV da mesma natureza respeitem mutuamente suas dimensões, especialmente se tal eixo representa uma grandeza temporal.** Por exemplo, os arquivos da pasta `flow_data` devem conter o mesmo número de linhas, ou seja, todas as usinas devem ter o mesmo número de anos de vazão natural histórica.
* `evaporation_data`
  * `coefficients`: contém arquivos CSV com uma coluna contendo os coeficientes de evaporação de cada mês (ordenado de 1 a 12) em $mm/Mês$. Se o arquivo para uma planta espefícica estiver ausente, seus valores serão considerados zero.
  * `polynomials`: Para algumas usinas com reservatório, é pertinente considerar sua área no momento de calcular sua evaporação. Para tal, os coeficientes dos polinômios Volume X Cota e Cota X Área são providos, para cada planta, na forma de um arquivo CSV com os coeficientes dispostos respectivamente na primeira e segunda linha, em ordem crescente de expoente da esquerda para a direita. Caso o arquivo para uma usina específica esteja ausente, sua área será considerada constante de acordo com o informado no arquivo `hidroplants_params.csv`. O polinômio deve considerar volume em $Hm^3$, cota em $m$, e Área em $Km^2$.
* `flow_data`: dados históricos de vazão natural para serem utilizados na simulação de maneira determinística. Dados estão dispostos, para cada usina, em um arquivo CSV com colunas correspondendo a meses (ordenado de 1 a 12) e linhas a anos (ordem crescente), em $m^3/s$. **Deve ser fornecido um arquivo para cada planta, mesmo que este seja nulo.**
* `generation_data`: os arquivos CSV nessa pasta seguem precisamente o modelo de arquivo de saída do SUISHI. Apesar dos arquivos estarem completos por fins de simplicidade, apenas as colunas `QTUR` (vazão turbinada em $m^3/s$), `VOLF` (volume final em $Hm^3$) e `GHID` (geração em $MW$) são consideradas na prática.
