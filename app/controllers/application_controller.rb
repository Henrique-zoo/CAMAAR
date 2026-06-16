class ApplicationController < ActionController::Base
  def current_usuario
    @current_usuario ||= Usuario.find_by(id: session[:usuario_id]) 
  end 
  helper_method :current_usuario
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes 

end
