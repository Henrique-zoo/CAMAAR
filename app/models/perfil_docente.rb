# app/models/perfil_docente.rb
class PerfilDocente < ApplicationRecord
  self.primary_key = :id

  belongs_to :usuario,
    class_name:  "Usuario",
    foreign_key: :id,
    inverse_of:  :perfil_docente

  belongs_to :departamento
end
