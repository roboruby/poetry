# Infrastructure smoke mailer: proves the Action Mailer stack end to end
# (delivery, url helpers, layout). Preview at /rails/mailers/system_mailer.
class SystemMailer < ApplicationMailer
  def ping(note: "poetry-docs mailer stack is alive")
    @note = note
    mail to: "ops@example.com", subject: "[poetry-docs] ping"
  end
end
