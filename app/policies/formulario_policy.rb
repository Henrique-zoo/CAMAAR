# frozen_string_literal: true

# Regras de acesso a formulários por departamento.
#
# Administradores só acessam formulários cuja turma pertence ao departamento do
# perfil logado.
class FormularioPolicy < ApplicationPolicy
  # Escopo de formulários visíveis ao usuário autenticado.
  class Scope < ApplicationPolicy::Scope
    # Restringe a relação de formulários ao departamento do administrador.
    #
    # Retorno:
    # - Formulários do departamento quando o usuário é administrador.
    # - Relação vazia para demais perfis.
    def resolve
      return scope.do_departamento(current_administrador.departamento) if administrador?

      scope.none
    end
  end

  # Permite listar formulários.
  #
  # Retorno:
  # - +true+ quando o usuário é administrador.
  def index?
    administrador?
  end

  # Permite visualizar um formulário específico.
  #
  # Retorno:
  # - +true+ quando o formulário pertence ao departamento do administrador.
  def show?
    formulario_do_departamento?
  end

  # Permite exibir o formulário de publicação.
  #
  # Retorno:
  # - Mesmo critério de +create?+.
  def new?
    create?
  end

  # Permite criar formulários.
  #
  # Retorno:
  # - +true+ quando o usuário é administrador.
  def create?
    administrador?
  end

  # Permite exportar respostas do formulário em CSV.
  #
  # Retorno:
  # - Mesmo critério de +show?+.
  def exportar_csv?
    show?
  end

  private

  # Verifica se o registro autorizado pertence ao departamento do administrador.
  #
  # Quando +record+ é a classe +Formulario+ (autorização genérica em +index+ ou
  # +create+), retorna +true+ para administradores sem comparar departamento.
  #
  # Retorno:
  # - +false+ para não-administradores.
  # - +true+ quando +record+ é a classe ou a turma do formulário pertence ao
  #   departamento do administrador logado.
  def formulario_do_departamento?
    return false unless administrador?
    return true if record.is_a?(Class)

    record.turma.departamento_id == current_administrador.departamento_id
  end
end
