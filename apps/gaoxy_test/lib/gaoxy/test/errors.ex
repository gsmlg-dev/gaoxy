defmodule Gaoxy.Test.SetupError do
  defexception [:message]
end

defmodule Gaoxy.Test.UnavailableError do
  defexception message: "Gaoxy.Test fixture state is unavailable or expired"
end

defmodule Gaoxy.Test.InvalidHandlerError do
  defexception [:message]
end

defmodule Gaoxy.Test.VerificationError do
  defexception [:message, :report]
end
