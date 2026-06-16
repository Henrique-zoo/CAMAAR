class ParticipacaoTurma < ApplicationRecord
  belongs_to :usuario
  belongs_to :turma
end
