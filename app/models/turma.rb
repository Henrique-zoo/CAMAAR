class Turma < ApplicationRecord
  belongs_to :materia

  # Relacionamento de muitos-para-muitos com Usuários
  has_many :participacoes_turma, dependent: :destroy
  has_many :usuarios, through: :participacoes_turma
end
