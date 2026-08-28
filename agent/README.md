# FatCat Agent

FatCat Agent is the product-specific, headless Hermes distribution boundary. It
owns conversation, planning, provider routing, skills, memory, and goals. FatCat
talks to it over a private Unix domain socket using the versioned protocol.

Hermes ACP's persistent session manager is used for `session/new`,
`session/load`, `session/list`, and `session/cancel`. The build stages the
pinned Hermes source and Python runtime inside the app.
