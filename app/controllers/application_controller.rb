# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  class NotAuthorizedError < StandardError; end

  rescue_from NotAuthorizedError, with: :usuario_nao_autorizado

  helper_method :current_usuario
  helper_method :current_adm
  helper_method :policy

  private

  def current_usuario
    @current_usuario ||= Usuario.find_by(id: session[:usuario_id])
  end

  def current_adm
    current_usuario&.perfil_adm
  end

  def authenticate_usuario!
    return if current_usuario.present?

    redirect_to login_path, alert: "Você precisa estar logado para acessar esta página."
  end

  def authorize!(record, query = nil)
    query ||= "#{action_name}?"

    return true if policy(record).public_send(query)

    raise NotAuthorizedError
  end

  def policy(record)
    policy_class_for(record).new(current_usuario, record)
  end

  def policy_scope(scope)
    policy_class_for(scope).scope(current_usuario, scope)
  end

  def policy_class_for(record_or_scope)
    model_class =
      if record_or_scope.is_a?(Class)
        record_or_scope
      else
        record_or_scope.class
      end

    "#{model_class.name}Policy".constantize
  end

  def usuario_nao_autorizado
    redirect_back(
      fallback_location: root_path,
      alert: "Você não tem permissão para realizar esta ação."
    )
  end
end
