Dado("que estou autenticado como administrador") do
  @admin ||= criar_administrador
  login_como(@admin)
end
