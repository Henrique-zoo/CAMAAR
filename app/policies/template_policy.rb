class TemplatePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if usuario&.administrador?

      scope.none
    end
  end

  def index?
    adm?
  end

  def show?
    adm?
  end

  def new?
    create?
  end

  def create?
    adm?
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
    adm?
  end

  private

  def dono_do_template?
    adm? && record.criado_por?(current_adm)
  end
end
