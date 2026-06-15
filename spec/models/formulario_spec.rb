require "rails_helper"

RSpec.describe Formulario, type: :model do
  describe "validações" do
    it "exige perfil administrativo" do
      formulario = described_class.new

      expect(formulario).not_to be_valid
      expect(formulario.errors[:perfil_adm]).to include("must exist")
    end
  end
end
