class ApplicationController < ActionController::Base
  USERS = { 'simon' => 'pw', 'hannes' => 'p2' }

  protect_from_forgery

private
  def authenticate
    authenticate_or_request_with_http_basic {|user, password| @user = user if USERS[user] == password}
  end
end
