defmodule Nota.Accounts.UserNotifier do
  @moduledoc """
  Handles email notifications for user account actions.
  Sends magic links, email confirmations, and other transactional emails.
  """
  import Swoosh.Email

  alias Nota.Mailer
  alias Nota.Accounts.User

  @sender "support@movo-soft.com"
  @signature "The Team at Nota"
  @sender_name "Nota"
  # @platform "Nota"

  # Delivers the email using the application mailer.
  defp deliver(body, subject, recipient) do
    email =
      new()
      |> to(recipient)
      |> from({@sender_name, @sender})
      |> subject(subject)
      # |> text_body(body)
      |> html_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  # === EMAILS --- AUTH
  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    [
      salutations("Hey #{user.email}"),
      "You have requested a change of email.",
      "The fact that you can read this means you're only a click away from doing so. Go ahead and click on the login button below:",
      [action: "Click to validate the email change", url: url],
      "If you changed your mind, just ignore this email.",
      "Best regards,",
      render_signature()
    ]
    |> frame()
    |> deliver("Update email instructions", user.email)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    [
      salutations("Hi #{user.email}"),
      "Quick and easy access to your account is just a click away.",
      [action: "Click to login", url: url],
      "If you didn't sign up with us, you can simply ignore this email.",
      "Thanks for choosing us!",
      "Best regards,",
      render_signature()
    ]
    |> frame
    |> deliver("Log in instructions", user.email)
  end

  defp deliver_confirmation_instructions(user, url) do
    [
      salutations("Hi #{user.email}"),
      "Quick and easy access to your account is just a click away.",
      [action: "Click to confirm your account and login", url: url],
      "If you didn't sign up with us, you can simply ignore this email.",
      "Thanks for choosing us!",
      "Best regards,",
      render_signature()
    ]
    |> frame()
    |> deliver("Confirmation instructions", user.email)
  end

  @doc """
  Deliver invite instructions to a new user.
  """
  def deliver_invite_instructions(user, url) do
    [
      salutations("Hi"),
      "You've been invited to join Nota!",
      "Click the button below to set up your account and get started:",
      [action: "Accept invitation", url: url],
      "If you weren't expecting this invitation, you can safely ignore this email.",
      "Best regards,",
      render_signature()
    ]
    |> frame()
    |> deliver("You've been invited to Nota", user.email)
  end

  # === HTML MAIL HELPERS
  defp render_signature(style \\ ""),
    do: "<p style='padding-top: 0.5rem; #{style}'>#{@signature}</p>"

  # shortcut for the formatted greeting line
  defp salutations(txt) when is_binary(txt) do
    "<p style='margin-top: 1rem; padding-bottom: 0.5rem'>#{txt},</p>"
  end

  # create HTML code for a block "<td>...</td>"
  defp render_block(p) when is_binary(p), do: "<tr><td><p>#{p}</p></td></tr>"

  defp render_block([action: action, url: url] = _keywords),
    do: """
    <tr><td align="center"><p style=""><span style="padding: 0.5rem 2rem; border-radius: 0.5rem; background-color:#18181b;">
    <a href="#{url}" target="movo" style="text-decoration: none; color: white;">#{action}</a></span></p>
    </td></tr>
    """

  # build HTML mail from text or list of text/links
  defp frame(blocks) when is_list(blocks) do
    # dbg(blocks)

    Enum.map_join(blocks, "\n", &render_block/1)
  end

  defp frame(body) when is_binary(body) do
    """
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <html dir="ltr"
      xmlns="http://www.w3.org/1999/xhtml"
      xmlns:o="urn:schemas-microsoft-com:office:office">
      <head>
        <meta charset="UTF-8">
        <meta content="width=device-width, initial-scale=1" name="viewport">
        <meta name="x-apple-disable-message-reformatting"><meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta content="telephone=no" name="format-detection"><title></title>
        <!--[if (mso 16)]><style type="text/css">a {text-decoration: none;}</style><![endif]-->
        <!--[if gte mso 9]><style>sup { font-size: 100% !important; }</style><![endif]-->
        <!--[if gte mso 9]><xml><o:OfficeDocumentSettings><o:AllowPNG></o:AllowPNG><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml><![endif]-->
        <!--[if mso]><style type="text/css">ul {margin: 0 !important;} ol {margin: 0 !important;} li {margin-left: 47px !important;}</style><![endif]-->
      </head>
      <body style="background-color: #f0f0f0;">
        <div dir="ltr" style="font-family: Helvetica, Arial, sans-serif.">
          <!--[if gte mso 9]><v:background xmlns:v="urn:schemas-microsoft-com:vml" fill="t"><v:fill type="tile" color="#f6f6f6"></v:fill></v:background><![endif]-->
          <table style="border-radius: 10px;" class="es-wrapper" width="100%" cellspacing="0" cellpadding="0"><tbody><tr><td valign="top" align="center">
            <table class="es-content-body" width="600" cellspacing="10" cellpadding="4" bgcolor="#ffffff">
            <tbody>
            #{body}
            </tbody>
            </table>
          </td></tr></tbody></table>
        </div>
      </body>
    </html>
    """
  end
end
