defmodule Mithril.OTP.SMS do
  @moduledoc false

  use HTTPoison.Base
  use Confex, otp_app: :mithril_api
  alias Mithril.ResponseDecoder

  def process_url(url), do: config()[:endpoint] <> url

  def process_request_options(options), do: Keyword.merge(config()[:hackney_options], options)

  def send(phone_number, body, type, headers \\ []) do
    "/sms/send"
    |> post!(Poison.encode!(%{phone_number: phone_number, body: body, type: type}), headers)
    |> ResponseDecoder.check_response()
  end
end
