# language: pt
Funcionalidade: Exportar resultados e controle departamental
  Como Administrador
  Quero gerenciar turmas do meu departamento e baixar os resultados em CSV
  A fim de avaliar o desempenho das turmas

  Contexto:
    Dado que existe um usuário administrador cadastrado no sistema

  @happy
  Cenário: Administrador baixa arquivo CSV com respostas de um formulário do seu departamento
    Dado que estou autenticado como administrador do "Departamento de Ciência da Computação"
    E que existe um formulário com respostas para a turma "Engenharia de Software"
    Quando eu acesso a página de relatórios do meu departamento
    E solicito a exportação do formulário da turma "Engenharia de Software"
    Então o download do arquivo CSV deve ser iniciado
    E o CSV deve conter os dados esperados das avaliações

  @happy
  Cenário: Administrador visualiza formulários restritos ao seu departamento
    Dado que estou autenticado como administrador do "Departamento de Ciência da Computação"
    E que existe a turma "Engenharia de Software" no meu departamento
    E que existe a turma "Cálculo 1" no "Departamento de Matemática"
    Quando eu acesso a página de relatórios
    Então devo ver o formulário da turma "Engenharia de Software" na lista
    E não devo ver o formulário da turma "Cálculo 1"

  @happy
  Cenário: Administrador exporta CSV de um formulário sem respostas
    Dado que estou autenticado como administrador do "Departamento de Ciência da Computação"
    E que existe um formulário sem respostas para a turma "Estrutura de Dados" do meu departamento
    Quando eu solicito a exportação do formulário da turma "Estrutura de Dados"
    Então o download do arquivo CSV deve ser iniciado
    E o arquivo CSV deve conter apenas a linha de cabeçalho

  @sad
  Cenário: Administrador tenta acessar turma de outro departamento
    Dado que estou autenticado como administrador do "Departamento de Ciência da Computação"
    E que a turma "Cálculo 1" pertence ao "Departamento de Matemática"
    Quando eu tento acessar a página de relatórios da turma "Cálculo 1"
    Então devo ver uma mensagem informando que não possuo permissão para acessar turmas de outros departamentos

  @sad
  Cenário: Administrador tenta exportar formulário de outro departamento sem permissão
    Dado que estou autenticado como administrador do "Departamento de Ciência da Computação"
    E que a turma "Cálculo 1" pertence ao "Departamento de Matemática"
    Quando eu tento forçar a exportação do CSV da turma "Cálculo 1"
    Então devo ver uma mensagem informando que a exportação não é permitida
    E o arquivo CSV não deve ser gerado

  @sad
  Cenário: Usuário não administrador tenta baixar arquivo CSV
    Dado que existe um usuário participante cadastrado no sistema
    E que estou autenticado como participante
    Quando eu tento acessar a rota de exportação de resultados em CSV
    Então devo ver uma mensagem informando que apenas administradores possuem acesso a este recurso