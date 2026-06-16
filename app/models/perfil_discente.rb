# app/models/perfil_discente.rb
class PerfilDiscente < ApplicationRecord
  self.primary_key = :id

  belongs_to :usuario,
    class_name:  "Usuario",
    foreign_key: :id,
    inverse_of:  :perfil_discente
end
