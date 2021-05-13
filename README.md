# Rack::SessionCounter

Rack::SessionCounter is a Rack middleware that handles tracking and logging of requests, both authenticated and anonymous.  This web app is configured with the beginnings of the SessionCounter, as well as a `Rack::BasicLogin` middleware to handle primitive login/logout.  It does so by setting a session value called `loginstate` equal to the username, only if an authorization header is passed with username:password credentials.  The password must be the same as the `TOKEN` passed to `Rack::BasicLogin`.  Currently, the app automatically increments counters for authenticated and anonymous calls.

Implement the following in the exercise, timeboxing your work to two hours:

- In addition to logging the overall authenticated vs anonymous call statistics, implement logging on a per-user basis
- Add in logic so `GET /_auth/most_active` returns a JSON body containing an array of the names and API calls of the 5 most active users (active is defined by the most number of API calls)
- Add in data persistence, so that if we shut off the server and turn it back on, it does not lose the current counts