# frozen_string_literal: true

class TemplatePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if usuario&.administrador?

      scope.none
    end
  end

  def index?
    administrador?
  end

  def show?
    administrador?
  end

  def new?
    create?
  end

  def create?
    administrador?
  end

  def edit?
    update?
  end

  def update?
    dono_do_template?
  end

  def destroy?
    dono_do_template?
  end

  def use?
    administrador?
  end

  private

  def dono_do_template?
    administrador? && record.criado_por?(current_administrador)
  end
end
