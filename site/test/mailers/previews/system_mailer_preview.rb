# Preview all emails at http://localhost:3000/rails/mailers/system_mailer
class SystemMailerPreview < ActionMailer::Preview
  def ping
    SystemMailer.ping
  end
end
