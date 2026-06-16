# app/models/perfil_adm.rb
class PerfilAdm < ApplicationRecord
  self.primary_key = :id

  belongs_to :usuario,
    class_name:  "Usuario",
    foreign_key: :id,
    inverse_of:  :perfil_adm

  belongs_to :departamento

  def admin?
    true
  end
end
