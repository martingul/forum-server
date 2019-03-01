module Users
  def self.signup(username, password)
    password_hash = Auth.hash(password)

    # store a new user instance and get the uid back
    conn = PG.connect(dbname: 'storage')
    conn.prepare('user_insert',
      'INSERT INTO users(username, password) VALUES($1, $2)
      RETURNING id AS uid')
    result = conn.exec_prepared('user_insert', [username, password_hash])
    # TODO check result
    uid = result[0]['uid']

    conn.close if conn
    result.clear if result

    sessid = Auth.create_session(uid)

    # redirect the user to index with session cookie
    view = View.new('index', username: username)
    body = view.render
    return Rack::Response.new(body, 302, {
      'Content-Type' => 'text/html',
      'Set-Cookie' => "sessid=#{sessid}; Path=/; HttpOnly",
      'Location' => '/'
    })
  rescue PG::Error => e
    sqlstate = e.result.error_field(PG::Result::PG_DIAG_SQLSTATE)

    if sqlstate == '23505' # unique username constraint error
      return View.finalize('login', 400, {
        username: username, username_taken: true
      })
    end
  end

  def self.get_user(req, username, user)
    # XXX req
    # TODO validate username
    # check if username exists
    conn = PG.connect(dbname: 'storage')
    conn.prepare('user_select',
      'SELECT username, date_created FROM users WHERE username = $1 LIMIT 1')
    result = conn.exec_prepared('user_select', [username])
    # TODO check result
    # username not found in database
    return Routes.not_found(req) if result.column_values(0).empty?

    date_created = result.column_values(1)[0]
    t_created = Time.parse(date_created).strftime("%B %e %Y")

    return View.finalize('user', 200, {
      username: username, date_created: t_created, user: user
    })
  end
end
