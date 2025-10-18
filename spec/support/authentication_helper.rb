module AuthenticationHelper
  # 為 request specs 提供的登入 helper
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  # 為 system specs 提供的登入 helper
  def sign_in_system(user)
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: 'password123'
    click_button "Sign in"
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
  config.include AuthenticationHelper, type: :system
end
