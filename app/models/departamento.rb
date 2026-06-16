class Departamento < ApplicationRecord
  has_many :perfis_adm
  has_many :perfis_docente
  has_many :materias, dependent: :destroy
end
