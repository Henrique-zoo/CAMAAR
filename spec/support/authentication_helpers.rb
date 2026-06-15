module AuthenticationHelpers
  def sign_in_as(usuario)
    allow_any_instance_of(ApplicationController).to receive(:current_usuario).and_return(usuario)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
