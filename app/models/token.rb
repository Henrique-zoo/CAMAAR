class Token < ApplicationRecord
  # Diz para o Rails buscar o usuário usando a coluna 'matricula_aluno' contra a 'matricula' do Usuário
  belongs_to :usuario, foreign_key: :matricula_aluno, primary_key: :matricula

  # Um método helper simples para checar se o token já venceu
  def expirado?
    expires_at < Time.current
  end
end
