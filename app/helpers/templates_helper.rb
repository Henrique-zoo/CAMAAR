module TemplatesHelper
  def letra_da_opcao(numero)
    numero = numero.to_i
    return "" unless numero.positive?

    quotient, remainder = (numero - 1).divmod(26)

    "#{letra_da_opcao(quotient)}#{(97 + remainder).chr}"
  end
end
