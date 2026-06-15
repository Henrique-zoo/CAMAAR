class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_usuario

  def current_usuario
    @current_usuario ||= Usuario.find_by(id: session[:usuario_id]) if session[:usuario_id]
  end

  def require_admin!
    return if current_usuario&.administrador?

    redirect_to(request.referrer || "/", alert: "Acesso não autorizado")
  end
end
