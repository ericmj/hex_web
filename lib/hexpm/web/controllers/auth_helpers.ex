defmodule Hexpm.Web.AuthHelpers do
  import Plug.Conn
  import Hexpm.Web.ControllerHelpers, only: [render_error: 3]

  alias Hexpm.Accounts.{Auth, Key}

  def authorized(conn, opts) do
    fun = Keyword.get(opts, :fun, fn _, _ -> true end)
    user = conn.assigns.current_user

    if user do
      authorized(conn, user, fun, opts)
    else
      error(conn, {:error, :missing})
    end
  end

  def maybe_authorized(conn, opts) do
    authorized(conn, conn.assigns.current_user, opts[:fun], opts)
  end

  defp authorized(conn, user, fun, opts) do
    only_basic = Keyword.get(opts, :only_basic, false)
    allow_unconfirmed = Keyword.get(opts, :allow_unconfirmed, false)
    domain = Keyword.get(opts, :domain)
    resource = Keyword.get(opts, :resource)
    key = conn.assigns.key
    email = conn.assigns.email

    cond do
      user && ((only_basic && key) || (!only_basic && !key)) ->
        error(conn, {:error, :missing})
      user && ((!email or !email.verified) && !allow_unconfirmed) ->
        error(conn, {:error, :unconfirmed})
      user && key && !verify_permissions?(key, domain, resource) ->
        error(conn, {:error, :domain})
      fun && !fun.(conn, user) ->
        error(conn, {:error, :auth})
      true ->
        conn
    end
  end

  defp verify_permissions?(_key, nil, _resource) do
    true
  end
  defp verify_permissions?(key, domain, resource) do
    Key.verify_permissions?(key, domain, resource)
  end

  def error(conn, error) do
    case error do
      {:error, :missing} ->
        unauthorized(conn, "missing authentication information")
      {:error, :invalid} ->
        unauthorized(conn, "invalid authentication information")
      {:error, :basic} ->
        unauthorized(conn, "invalid username and password combination")
      {:error, :key} ->
        unauthorized(conn, "invalid username and API key combination")
      {:error, :unconfirmed} ->
        forbidden(conn, "email not verified")
      {:error, :revoked_key} ->
        unauthorized(conn, "API key revoked")
      {:error, :domain} ->
        unauthorized(conn, "key not authorized for this action")
      {:error, :auth} ->
        forbidden(conn, "account not authorized for this action")
    end
  end

  def authenticate(conn) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> credentials] ->
        basic_auth(credentials)
      [key] ->
        key_auth(key)
      _ ->
        {:error, :missing}
    end
  end

  defp basic_auth(credentials) do
    case String.split(Base.decode64!(credentials), ":", parts: 2) do
      [username_or_email, password] ->
        case Auth.password_auth(username_or_email, password) do
          {:ok, result} -> {:ok, result}
          :error -> {:error, :basic}
        end
      _ ->
        {:error, :invalid}
    end
  end

  defp key_auth(key) do
    case Auth.key_auth(key) do
      {:ok, result} -> {:ok, result}
      :error -> {:error, :key}
      :revoked -> {:error, :revoked_key}
    end
  end

  def unauthorized(conn, reason) do
    conn
    |> put_resp_header("www-authenticate", "Basic realm=hex")
    |> render_error(401, message: reason)
  end

  def forbidden(conn, reason) do
    render_error(conn, 403, message: reason)
  end

  def package_owner?(_, nil) do
    false
  end
  def package_owner?(%Plug.Conn{} = conn, user) do
    package_owner?(conn.assigns.package, user)
  end
  def package_owner?(%Hexpm.Repository.Package{} = package, user) do
    Hexpm.Repository.Packages.owner?(package, user)
  end

  def maybe_package_owner?(%Plug.Conn{} = conn, user) do
    maybe_package_owner?(conn.assigns[:package], user)
  end
  def maybe_package_owner?(nil, _user) do
    true
  end
  def maybe_package_owner?(%Hexpm.Repository.Package{} = package, user) do
    Hexpm.Repository.Packages.owner?(package, user)
  end

  def repository_access?(%Plug.Conn{} = conn, user) do
    repository_access?(conn.assigns.repository, user)
  end
  def repository_access?(%Hexpm.Repository.Repository{} = repository, user) do
    Hexpm.Repository.Repositories.access?(repository, user)
  end

  def correct_user?(%Plug.Conn{} = conn, user) do
    correct_user?(conn.params["name"], user)
  end
  def correct_user?(username_or_email, user) when is_binary(username_or_email) do
    username_or_email in [user.username, user.email]
  end
end
